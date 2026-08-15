# install.ps1 - DeepSeek Harness 一键安装（便携免安装版）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1
#        [-UseSystemNode] [-NodeVersion 22.19.0] [-Registry https://...] [-Force] [-Pnpm] [-NoPrompts]
# 环境变量: DSH_NODE_VERSION / DSH_NPM_REGISTRY / DSH_NPM_PACKAGE / DSH_USE_SYSTEM_NODE
param(
  [switch]$UseSystemNode,
  [string]$NodeVersion,
  [string]$Registry,
  [switch]$Force,
  [switch]$Pnpm,
  [switch]$NoPrompts
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

$pkgBase = if ($env:DSH_NPM_PACKAGE) { $env:DSH_NPM_PACKAGE } else { '@deepseek-ai/dsh' }

Write-Host '======================================================' -ForegroundColor Magenta
Write-Host '  DeepSeek Harness 一键安装 (便携免安装版)' -ForegroundColor Magenta
Write-Host '  项目: https://github.com/deepseek-ai/deepseek-harness' -ForegroundColor Magenta
Write-Host '  本工具不写注册表、不改系统环境变量，全部文件放在本目录。' -ForegroundColor Magenta
Write-Host '======================================================' -ForegroundColor Magenta

# ---- 0. 系统检查 ----
if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Err '需要 Windows PowerShell 5.1+'; exit 1 }
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
if ($arch -eq 'AMD64') { $arch = 'x64' }
if ($arch -ne 'x64' -and $arch -ne 'arm64') { Write-Err ("暂不支持架构: $arch (仅支持 x64 / arm64)"); exit 1 }

# ---- 1. 准备 Node.js ----
Write-Step '第 1 步 / 4: 准备 Node.js 运行时'
$mode = $null

# 1a. 便携版已存在且版本满足 -> 直接复用
if (Test-PortableNode) {
  $pv = Get-PortableNodeVersion
  if (Test-NodeSatisfies $pv) {
    $mode = 'portable'
    Write-Info ("使用已有的便携 Node.js: $pv")
  } else {
    Write-Warn ("便携 Node 版本 $pv 不满足要求 (需要 ^22.19.0 或 >=24)，重新下载...")
    Remove-Item $NodeDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# 1b. 选择系统 Node（仅在用户同意或显式指定时）
if (-not $mode) {
  $sys = Get-SystemNodeInfo
  $useSys = $false
  if ($UseSystemNode -or $env:DSH_USE_SYSTEM_NODE) { $useSys = $true }
  elseif ($sys.Exists -and (Test-NodeSatisfies $sys.Version) -and -not $Force -and -not $NoPrompts) {
    $ans = Read-Host ("检测到系统 Node.js $($sys.Version)。直接使用系统 Node (免下载)？[y/N]")
    if ($ans -match '^[yY]') { $useSys = $true }
  }
  if ($useSys -and $sys.Exists) {
    $mode = 'system'
    Write-Info ("使用系统 Node.js: $($sys.Version)")
  } elseif ($useSys) {
    Write-Warn '选择了系统 Node 但未找到，将继续下载便携版'
  }
}

# 1c. 下载便携 Node
if (-not $mode) {
  $ver = if ($NodeVersion) { $NodeVersion.Trim().TrimStart('v') } else { Get-RecommendedNodeVersion }
  Write-Info "正在下载 Node.js v$ver (win-$arch 便携版)..."
  Write-Info '[DSH-PROG] start:node'
  New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
  $zip = Join-Path $ToolsDir ("node-v$ver-win-$arch.zip")
  # 下载镜像: 默认 npmmirror 优先(国内快)，失败自动切换；可用环境变量 DSH_NODE_MIRROR 固定
  $mirror = if ($env:DSH_NODE_MIRROR) { $env:DSH_NODE_MIRROR.ToLower() } else { 'auto' }
  if (-not $NoPrompts -and $mirror -eq 'auto') {
    Write-Info '   Node.js 下载镜像:'
    Write-Info '   [1] 自动 (npmmirror 优先，失败自动切换) -- 推荐'
    Write-Info '   [2] 仅 npmmirror.com (国内)'
    Write-Info '   [3] 仅华为云'
    Write-Info '   [4] 仅官方 nodejs.org'
    $mc = Read-Host '请选择 [1-4]，默认 1'
    switch ($mc) {
      '2' { $mirror = 'npmmirror' }
      '3' { $mirror = 'huawei' }
      '4' { $mirror = 'official' }
    }
  }
  $urls = @()
  switch ($mirror) {
    'npmmirror' { $urls += "https://npmmirror.com/mirrors/node/v$ver/node-v$ver-win-$arch.zip" }
    'huawei'    { $urls += "https://mirrors.huaweicloud.com/nodejs/v$ver/node-v$ver-win-$arch.zip" }
    'official'  { $urls += "https://nodejs.org/dist/v$ver/node-v$ver-win-$arch.zip" }
    default {
      $urls += "https://npmmirror.com/mirrors/node/v$ver/node-v$ver-win-$arch.zip"
      $urls += "https://nodejs.org/dist/v$ver/node-v$ver-win-$arch.zip"
      $urls += "https://mirrors.huaweicloud.com/nodejs/v$ver/node-v$ver-win-$arch.zip"
    }
  }
  if (-not (Invoke-Download -Urls $urls -OutFile $zip -What 'Node.js')) {
    Write-Err 'Node.js 下载失败。'
    Write-Err '建议: 1) 检查网络/代理; 2) 用 -NodeVersion 指定版本重试; 3) 设置 DSH_NODE_MIRROR=npmmirror 后重试; 4) 安装系统 Node 后用 -UseSystemNode。'
    exit 1
  }
  Write-Info '正在解压...'
  $tmp = Join-Path $ToolsDir '._node-extract'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  $extractOk = $false
  try { Expand-Archive -Path $zip -DestinationPath $tmp -Force; $extractOk = $true } catch {}
  if (-not $extractOk) {
    & tar.exe -xf $zip -C $tmp 2>$null
    if ($LASTEXITCODE -eq 0) { $extractOk = $true }
  }
  if (-not $extractOk) { Write-Err 'Node.js 压缩包解压失败'; exit 1 }
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  if (-not $inner) { Write-Err 'Node.js 压缩包内容异常'; exit 1 }
  Move-Item $inner.FullName $NodeDir
  Remove-Item $tmp -Recurse -Force
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  $pv = Get-PortableNodeVersion
  if (-not (Test-NodeSatisfies $pv)) { Write-Err ("Node 校验失败: $pv"); exit 1 }
  $mode = 'portable'
  Write-Info ('[DSH-PROG] end:node')
  Write-Info ("便携 Node.js 就绪: $pv")
}

# ---- 2. 选择 npm 软件源 ----
Write-Step '第 2 步 / 4: 选择 npm 软件源'
if (-not $Registry -and -not $env:DSH_NPM_REGISTRY -and -not $NoPrompts) {
  Write-Info '   [1] 自动 (npmmirror 优先，失败自动切换) -- 推荐'
  Write-Info '   [2] 仅 npmmirror.com (国内镜像)'
  Write-Info '   [3] 仅华为云镜像'
  Write-Info '   [4] 自定义 URL'
  $c = Read-Host '请选择 [1-4]，默认 1'
  switch ($c) {
    '2' { $Registry = 'https://registry.npmmirror.com/' }
    '3' { $Registry = 'https://repo.huaweicloud.com/repository/npm/' }
    '4' { $Registry = Read-Host '请输入 npm registry URL' }
    default { $Registry = '' }
  }
}
if (-not $Registry -and $env:DSH_NPM_REGISTRY) { $Registry = $env:DSH_NPM_REGISTRY }
$registries = @()
if ($Registry) { $registries += $Registry }
# 自动模式 npmmirror 优先（国内快），官方源对国内网络常常很慢
$registries += 'https://registry.npmmirror.com/', 'https://registry.npmjs.org/', 'https://repo.huaweicloud.com/repository/npm/'
$registries = $registries | Select-Object -Unique

# npm 通用参数: 缩短单源超时(30s)与重试(1次)以便快速切换；关闭进度条；http 级日志方便面板显示下载进度
$npmExtra = @('--fetch-timeout=30000', '--fetch-retries=1', '--progress=false', '--loglevel=http', '--no-audit', '--no-fund')

# ---- 3. 全局安装 dsh ----
Write-Step '第 3 步 / 4: 安装 DeepSeek Harness (dsh)'
New-Item -ItemType Directory -Path $NpmCacheDir -Force | Out-Null
New-Item -ItemType Directory -Path $DshHomeDir -Force | Out-Null

if ($mode -eq 'portable') {
  $npmCmd = Join-Path $NodeDir 'npm.cmd'
  $env:PATH = "$NodeDir;$env:PATH"
} else {
  $npmCmd = (Get-Command npm -ErrorAction SilentlyContinue).Source
}
if (-not $npmCmd -or -not (Test-Path $npmCmd)) { Write-Err '找不到 npm，请检查 Node 安装'; exit 1 }

Write-Info '正在下载并安装 DeepSeek Harness（包含 Web 界面，包较大，首次约需 1~5 分钟，请耐心等待）...'
Write-Info '[DSH-PROG] start:npm'
$installed = $false
foreach ($reg in $registries) {
  Write-Info ("  使用源: $reg")
  & $npmCmd install -g $pkgBase --registry $reg @npmExtra
  if ($LASTEXITCODE -eq 0) { $installed = $true; break }
  Write-Warn ("  安装失败 (exit=$LASTEXITCODE)，尝试下一个源...")
}
if (-not $installed) {
  Write-Err 'DeepSeek Harness 安装失败。'
  Write-Err '常见原因: 网络不通 / 需要代理 / 防火墙拦截。可设置环境变量 HTTPS_PROXY 后重试，或用 -Registry 指定可用镜像。'
  exit 1
}
Write-Info 'DeepSeek Harness 安装成功。'
Write-Info '[DSH-PROG] end:npm'

# 可选: pnpm (dsh plugin 插件管理需要)
$doPnpm = $Pnpm
if (-not $doPnpm -and -not $NoPrompts -and -not $Force) {
  $ans = Read-Host '是否同时安装 pnpm (用于 dsh 插件管理)？[y/N]'
  if ($ans -match '^[yY]') { $doPnpm = $true }
}
if ($doPnpm) {
  Write-Info '[DSH-PROG] start:pnpm'
  foreach ($reg in $registries) {
    & $npmCmd install -g pnpm --registry $reg @npmExtra
    if ($LASTEXITCODE -eq 0) { break }
  }
  if ((Get-Command pnpm -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $NodeDir 'pnpm.cmd'))) {
    Write-Info 'pnpm 安装成功。'
  } else {
    Write-Warn 'pnpm 安装失败，可稍后手动执行: npm install -g pnpm'
  }
  Write-Info '[DSH-PROG] end:pnpm'
}

# ---- 4. 验证与收尾 ----
Write-Step '第 4 步 / 4: 验证安装'
Write-Info '[DSH-PROG] start:verify'
$dshBin = Get-DshBin
$dshVer = '未知'
if ($dshBin) {
  try { $dshVer = ((& $dshBin --version 2>&1) -join ' ').Trim() } catch {}
  Write-Info ("  DeepSeek Harness 版本: $dshVer")
} else {
  Write-Warn '未找到 DeepSeek Harness 命令，请检查上方安装日志'
}

$nodeV = Get-PortableNodeVersion
if (-not $nodeV) { $nodeV = (Get-SystemNodeInfo).Version }
$infoLines = @(
  'DeepSeek Harness 便携版安装信息',
  ('安装时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
  ('模式: ' + $mode),
  ('Node.js: ' + $nodeV),
  ('dsh: ' + $dshVer)
)
$infoLines | Set-Content (Join-Path $ToolsDir 'install-info.txt') -Encoding UTF8
Write-Info '[DSH-PROG] end:verify'

Write-Host ''
Write-Host '======================================================' -ForegroundColor Green
Write-Host '  安装完成!' -ForegroundColor Green
Write-Host '  启动 Web UI : 双击  其他工具\start-web.cmd   (http://127.0.0.1:3080)' -ForegroundColor Green
Write-Host '  dsh 命令行  : 双击  其他工具\dsh.cmd  (可执行 dsh web / dsh --help 等)' -ForegroundColor Green
Write-Host '  升级        : 双击  其他工具\update.cmd' -ForegroundColor Green
Write-Host '  卸载        : 双击  其他工具\uninstall.cmd' -ForegroundColor Green
Write-Host '  用户数据    : data\dsh  (可用环境变量 DSH_HOME 重定向)' -ForegroundColor Green
Write-Host '======================================================' -ForegroundColor Green
exit 0
