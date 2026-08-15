# common.ps1 - DeepSeek Harness 便携版安装器共享函数
# 由 install.ps1 / start-web.ps1 / update.ps1 / uninstall.ps1 点源(dot-source)使用

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ToolsDir    = Join-Path $Root 'tools'
$NodeDir     = Join-Path $ToolsDir 'node'
$NpmCacheDir = Join-Path $ToolsDir 'npm-cache'
$DataDir     = Join-Path $Root 'data'
$DshHomeDir  = Join-Path $DataDir 'dsh'

# 让 dsh 的用户数据、npm 缓存全部留在本目录内 -> 真正的"免安装/绿色便携"
$env:DSH_HOME        = $DshHomeDir
$env:npm_config_cache = $NpmCacheDir

# ---------------- 输出辅助 ----------------
function Write-Step { param([string]$m) Write-Host ''; Write-Host ('==> ' + $m) -ForegroundColor Cyan }
function Write-Info { param([string]$m) Write-Host $m }
function Write-Warn { param([string]$m) Write-Host ('[警告] ' + $m) -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host ('[错误] ' + $m) -ForegroundColor Red }

# ---------------- Node 版本判定：dsh 引擎要求 ^22.19.0 || >=24.0.0 ----------------
function Test-NodeSatisfies {
  param([string]$Version)
  if ([string]::IsNullOrWhiteSpace($Version)) { return $false }
  try {
    $v = [version]($Version.Trim().TrimStart('v'))
    if ($v.Major -eq 22 -and $v -ge [version]'22.19.0') { return $true }
    if ($v.Major -ge 24) { return $true }
  } catch {}
  return $false
}

function Get-PortableNodeVersion {
  $exe = Join-Path $NodeDir 'node.exe'
  if (-not (Test-Path $exe)) { return $null }
  try { $v = (& $exe --version 2>$null) -join ''; return $v.Trim() } catch { return $null }
}

function Get-SystemNodeInfo {
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if (-not $cmd) { return @{ Exists = $false; Version = $null; Path = $null } }
  try {
    $v = (& node --version 2>$null) -join ''
    return @{ Exists = $true; Version = $v.Trim(); Path = $cmd.Source }
  } catch { return @{ Exists = $false; Version = $null; Path = $null } }
}

# 自动挑选最新 v22 LTS；可用环境变量 DSH_NODE_VERSION 固定版本
# 优先从 npmmirror 拉版本列表（国内快），失败再试官方
function Get-RecommendedNodeVersion {
  if ($env:DSH_NODE_VERSION) { return $env:DSH_NODE_VERSION.Trim().TrimStart('v') }
  $srcs = @('https://npmmirror.com/mirrors/node/index.json', 'https://nodejs.org/dist/index.json')
  foreach ($s in $srcs) {
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      $ProgressPreference = 'SilentlyContinue'
      $r = Invoke-WebRequest -UseBasicParsing -Uri $s -TimeoutSec 15 -Headers @{ 'User-Agent' = 'dsh-portable-installer' }
      $list = $r.Content | ConvertFrom-Json
      $hit = $list | Where-Object { $_.version -like 'v22.*' -and $_.lts } | Select-Object -First 1
      if ($hit) { return $hit.version.TrimStart('v') }
    } catch {}
  }
  return '22.19.0'
}

# ---------------- 下载：按顺序尝试多个镜像 ----------------
# 优先使用 curl.exe（Windows 10 自带）：带连接超时(10s)与总超时(60s)，避免卡住；
# 每个镜像失败后立即切换下一个；下载完成后校验 ZIP 魔数，防止拿到错误页面。
function Invoke-Download {
  param([string[]]$Urls, [string]$OutFile, [string]$What)
  foreach ($u in $Urls) {
    Write-Info ('    尝试: ' + $u)
    $ok = $false
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
      & curl.exe -s -S -L --fail --connect-timeout 10 --max-time 60 -o $OutFile $u
      if ($LASTEXITCODE -eq 0) { $ok = $true }
    } else {
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $OutFile -TimeoutSec 60 -Headers @{ 'User-Agent' = 'dsh-portable-installer' }
        $ok = $true
      } catch {
        Write-Warn (($What + ' 下载失败: ') + $_.Exception.Message)
      }
    }
    if ($ok) {
      $valid = $false
      try {
        if (Test-Path $OutFile) {
          $len = (Get-Item $OutFile).Length
          if ($len -gt 100000) {
            $fs = [System.IO.File]::OpenRead($OutFile)
            try {
              $magic = New-Object byte[] 2
              $null = $fs.Read($magic, 0, 2)
            } finally { $fs.Close() }
            if ($magic[0] -eq 0x50 -and $magic[1] -eq 0x4B) { $valid = $true }
          }
        }
      } catch {}
      if ($valid) { return $true }
      Write-Warn (($What + ' 下载内容无效(非 zip)，尝试下一个镜像...'))
      Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }
  }
  return $false
}

# ---------------- 解析 dsh 可执行文件：便携优先，否则取 PATH 中的 dsh ----------------
function Get-DshBin {
  $p = Join-Path $NodeDir 'dsh.cmd'
  if (Test-Path $p) { return $p }
  $sys = Get-Command dsh -ErrorAction SilentlyContinue
  if ($sys) { return 'dsh' }
  return $null
}

function Test-PortableNode {
  return (Test-Path (Join-Path $NodeDir 'node.exe'))
}
