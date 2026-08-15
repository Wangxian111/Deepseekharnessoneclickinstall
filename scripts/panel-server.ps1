# panel-server.ps1 - DeepSeek Harness 本地网页控制面板（微型 HTTP 服务）
# 双击 panel.cmd 启动；默认地址 http://127.0.0.1:38765
# 仅监听 127.0.0.1 回环地址：不需要管理员权限、不触发防火墙。
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\panel-server.ps1 [-Port 38765] [-NoBrowser]
param(
  [int]$Port = 0,
  [switch]$NoBrowser
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

$script:LogDir       = Join-Path $env:TEMP 'dsh-panel-logs'
$script:IndexPath    = Join-Path $Root 'webpanel\index.html'
$script:Jobs         = @{}
$script:JobProgress  = @{}
$script:WebProbe     = 3080
New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null

# ---------------- 基础工具 ----------------
function Test-LocalPort {
  param([int]$P)
  $c = New-Object System.Net.Sockets.TcpClient
  try {
    $ar = $c.BeginConnect('127.0.0.1', $P, $null, $null)
    if ($ar.AsyncWaitHandle.WaitOne(400)) { $c.EndConnect($ar); return $true }
    return $false
  } catch { return $false } finally { $c.Close() }
}

function Find-HeaderEnd {
  param([byte[]]$Bytes)
  for ($i = 0; $i -le $Bytes.Length - 4; $i++) {
    if ($Bytes[$i] -eq 13 -and $Bytes[$i + 1] -eq 10 -and $Bytes[$i + 2] -eq 13 -and $Bytes[$i + 3] -eq 10) { return $i }
  }
  return -1
}

function Send-Response {
  param($Client, [int]$Status, [string]$ContentType, [byte[]]$Body)
  $reason = switch ($Status) { 200 { 'OK' } 204 { 'No Content' } 400 { 'Bad Request' } 404 { 'Not Found' } 500 { 'Internal Server Error' } default { 'OK' } }
  $head = "HTTP/1.1 $Status $reason`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
  $stream = $Client.GetStream()
  $stream.Write($hb, 0, $hb.Length)
  if ($Body.Length -gt 0) { $stream.Write($Body, 0, $Body.Length) }
  $stream.Flush()
}

function Send-Json {
  param($Client, [int]$Status, $Obj)
  $json = $Obj | ConvertTo-Json -Compress -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  Send-Response $Client $Status 'application/json; charset=utf-8' $bytes
}

# ---------------- 状态 ----------------
function Get-Status {
  $portNode = Get-PortableNodeVersion
  $sys = Get-SystemNodeInfo
  $dshBin = Get-DshBin
  $dshVer = $null
  if ($dshBin) { try { $dshVer = ((& $dshBin --version 2>&1) -join ' ').Trim() } catch {} }
  [pscustomobject]@{
    root            = $Root
    dshHome         = $DshHomeDir
    portableNode    = [bool](Test-PortableNode)
    portableNodeVer = $portNode
    systemNode      = $sys.Exists
    systemNodeVer   = $sys.Version
    dshInstalled    = [bool]$dshBin
    dshVersion      = $dshVer
    pnpm            = (Test-Path (Join-Path $NodeDir 'pnpm.cmd'))
    webRunning      = (Test-LocalPort $script:WebProbe)
    webUrl          = "http://127.0.0.1:$script:WebProbe"
    time            = (Get-Date -Format 'HH:mm:ss')
  }
}

# ---------------- 后台任务（安装/升级/卸载） ----------------
# 注意: 不要用 .NET Process 的 OutputDataReceived 事件来捕获子进程输出——
# PowerShell 5.1 的事件处理器在后台线程上无法解析闭包变量，会触发致命错误导致整个面板崩溃。
# 这里让 cmd.exe 用 > 重定向把子进程输出写入日志文件（子脚本已将输出编码设为 UTF-8）。
function Start-RunJob {
  param([string]$Id, [string]$ScriptPath, [string]$ArgsLine, [string]$Label)
  $log = Join-Path $script:LogDir ($Id + '.log')
  Remove-Item $log -Force -ErrorAction SilentlyContinue
  $inner = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $ScriptPath + '"' + $ArgsLine + ' > "' + $log + '" 2>&1'
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'cmd.exe'
  $psi.Arguments = '/s /c "' + $inner + '"'
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $p.Start() | Out-Null
  $script:Jobs[$Id] = @{ Id = $Id; Process = $p; Log = $log; Label = $Label; Started = Get-Date }
  $script:JobProgress[$Id] = New-ProgressState
  Write-Host ("[面板] 任务已启动: " + $Label + " (id=" + $Id + ")")
}

function Get-JobLog {
  param([string]$Id, [long]$Offset)
  $result = @{ job = $Id; running = $false; exitCode = $null; lines = '' }
  $job = $script:Jobs[$Id]
  if ($job) {
    try { $result.running = -not $job.Process.HasExited } catch { $result.running = $false }
    if (-not $result.running) { try { $result.exitCode = $job.Process.ExitCode } catch {} }
    if (Test-Path $job.Log) {
      $fs = [System.IO.File]::Open($job.Log, 'Open', 'Read', 'ReadWrite')
      try {
        $fs.Seek($Offset, 'Begin') | Out-Null
        $len = $fs.Length - $Offset
        if ($len -gt 0) {
          $buf = New-Object byte[] $len
          $fs.Read($buf, 0, $len) | Out-Null
          $result.lines = [System.Text.Encoding]::UTF8.GetString($buf)
        }
      } finally { $fs.Close() }
    }
  }
  return $result
}

# ---------------- 进度计算（基于安装脚本输出的 [DSH-PROG] 标记） ----------------
function Get-PhaseDefaults {
  return @{
    node      = @{ label = '下载便携 Node.js'; weight = 20; eta = 90 }
    npm       = @{ label = '下载并安装 DeepSeek Harness (npm)'; weight = 75; eta = 240 }
    pnpm      = @{ label = '安装 pnpm'; weight = 5; eta = 60 }
    verify    = @{ label = '验证安装'; weight = 5; eta = 15 }
    uninstall = @{ label = '卸载中'; weight = 100; eta = 30 }
  }
}

function New-ProgressState {
  return @{ offset = 0; phases = New-Object System.Collections.Generic.List[object]; active = $null }
}

function Update-JobProgress {
  param($State, [string]$NewText)
  foreach ($line in ($NewText -split "`r?`n")) {
    if ($line -match '\[DSH-PROG\] (start|end):([a-z]+)') {
      $kind = $matches[1]
      $name = $matches[2]
      $phase = $State.phases | Where-Object { $_.name -eq $name } | Select-Object -First 1
      if ($kind -eq 'start') {
        if (-not $phase) {
          $phase = @{ name = $name; start = Get-Date; end = $null; value = $null }
          $State.phases.Add($phase)
        }
        $State.active = $name
      } else {
        if ($phase) { $phase.end = Get-Date }
        if ($State.active -eq $name) { $State.active = $null }
      }
    } elseif ($line -match '\[DSH-PROG\] value:([a-z]+):([0-9.]+)') {
      $phase = $State.phases | Where-Object { $_.name -eq $matches[1] } | Select-Object -First 1
      if ($phase) { $phase.value = [double]$matches[2] }
    }
  }
}

function Get-JobProgress {
  param([string]$Id, [datetime]$Now)
  $job = $script:Jobs[$Id]
  if (-not $job) { return @{ found = $false } }
  $state = $script:JobProgress[$Id]
  if (-not $state) { $state = New-ProgressState; $script:JobProgress[$Id] = $state }
  # 增量读取日志中的进度标记
  if (Test-Path $job.Log) {
    $fs = [System.IO.File]::Open($job.Log, 'Open', 'Read', 'ReadWrite')
    try {
      $len = $fs.Length
      if ($len -gt $state.offset) {
        $fs.Seek($state.offset, 'Begin') | Out-Null
        $buf = New-Object byte[] ($len - $state.offset)
        $fs.Read($buf, 0, $buf.Length) | Out-Null
        $state.offset = $len
        Update-JobProgress -State $state -NewText ([System.Text.Encoding]::UTF8.GetString($buf))
      }
    } finally { $fs.Close() }
  }
  $done = $false
  try { $done = $job.Process.HasExited } catch { $done = $true }
  $defaults = Get-PhaseDefaults
  $totalW = 0.0
  $accW = 0.0
  foreach ($ph in $state.phases) {
    $d = $defaults[$ph.name]
    if (-not $d) { continue }
    $w = [double]$d.weight
    $totalW += $w
    if ($ph.end) { $accW += $w }
    elseif ($null -ne $ph.value) { $accW += $w * [Math]::Min(1.0, [double]$ph.value) }
    else {
      $e = [Math]::Max(0.0, ($Now - $ph.start).TotalSeconds)
      $v = [Math]::Min(0.95, $e / [double]$d.eta)
      $accW += $w * $v
    }
  }
  $percent = 0
  if ($totalW -gt 0) { $percent = [Math]::Min(100, [Math]::Round($accW / $totalW * 100)) }
  $active = $state.active
  if (-not $active) {
    $last = $state.phases | Select-Object -Last 1
    if ($last -and -not $last.end) { $active = $last.name }
  }
  $label = '准备中…'
  $eta = 0
  if ($done) {
    $label = '完成'
  } elseif ($active -and $defaults[$active]) {
    $d = $defaults[$active]
    $label = $d.label
    $start = ($state.phases | Where-Object { $_.name -eq $active } | Select-Object -First 1).start
    $e = [Math]::Max(0.0, ($Now - $start).TotalSeconds)
    $eta = [Math]::Max(0, [int]($d.eta - $e))
  } elseif ($state.phases.Count -eq 0 -and -not $done) {
    $label = '准备中…（预计 1~5 分钟，视网速）'
  }
  $elapsed = 0
  if ($job.Started) { $elapsed = [int][Math]::Max(0, ($Now - $job.Started).TotalSeconds) }
  return @{
    found = $true
    percent = $percent
    label = $label
    etaSeconds = $eta
    elapsed = $elapsed
    running = (-not $done)
    active = $active
    done = $done
  }
}

# ---------------- 请求处理 ----------------
function Handle-Request {
  param($Client)
  $stream = $Client.GetStream()
  try { $stream.ReadTimeout = 8000 } catch {}
  $ms = New-Object System.IO.MemoryStream
  $buf = New-Object byte[] 8192
  $all = $null
  $headerEnd = -1
  while ($headerEnd -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $ms.Write($buf, 0, $n)
    $all = $ms.ToArray()
    if ($all.Length -gt 262144) { break }
    $headerEnd = Find-HeaderEnd $all
  }
  if ($headerEnd -lt 0) { return }
  $headBytes = New-Object byte[] $headerEnd
  [Array]::Copy($all, $headBytes, $headerEnd)
  $head = [System.Text.Encoding]::ASCII.GetString($headBytes)
  $lines = $head -split "`r`n"
  if ($lines.Count -eq 0) { return }
  $parts = $lines[0] -split ' '
  if ($parts.Count -lt 2) { return }
  $method = $parts[0]
  $target = $parts[1]

  $path = $target
  $query = ''
  $qi = $target.IndexOf('?')
  if ($qi -ge 0) { $path = $target.Substring(0, $qi); $query = $target.Substring($qi + 1) }
  try { $path = [System.Uri]::UnescapeDataString($path) } catch {}

  $q = @{}
  if ($query) {
    foreach ($pair in ($query -split '&')) {
      $kv = $pair -split '=', 2
      if ($kv.Count -eq 2) {
        try { $q[[System.Uri]::UnescapeDataString($kv[0])] = [System.Uri]::UnescapeDataString($kv[1]) } catch {}
      }
    }
  }

  Write-Host ("[面板] " + $method + " " + $path)

  if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
    if (Test-Path $script:IndexPath) {
      $bytes = [System.IO.File]::ReadAllBytes($script:IndexPath)
      Send-Response $Client 200 'text/html; charset=utf-8' $bytes
    } else { Send-Json $Client 404 @{ error = 'index.html not found: ' + $script:IndexPath } }
    return
  }
  if ($method -eq 'GET' -and $path -eq '/favicon.ico') { Send-Response $Client 204 'image/x-icon' ([byte[]]@()); return }

  if ($method -eq 'GET' -and $path -eq '/api/status') { Send-Json $Client 200 (Get-Status); return }

  # 返回仍在运行的任务列表（供页面刷新后接回日志与停止按钮）
  if ($method -eq 'GET' -and $path -eq '/api/jobs') {
    $list = @()
    foreach ($k in @($script:Jobs.Keys)) {
      $j = $script:Jobs[$k]
      try { $running = -not $j.Process.HasExited } catch { $running = $false }
      if ($running) { $list += [pscustomobject]@{ id = $k; label = $j.Label } }
    }
    Send-Json $Client 200 @{ jobs = $list }
    return
  }

  if ($method -eq 'GET' -and $path -eq '/api/log') {
    $id = $q['job']
    $off = 0L
    if ($q['offset']) { [long]::TryParse($q['offset'], [ref]$off) | Out-Null }
    if (-not $id) { Send-Json $Client 400 @{ error = 'missing job' }; return }
    Send-Json $Client 200 (Get-JobLog -Id $id -Offset $off)
    return
  }

  if ($method -eq 'GET' -and $path -eq '/api/progress') {
    $id = $q['job']
    if (-not $id) { Send-Json $Client 400 @{ error = 'missing job' }; return }
    Send-Json $Client 200 (Get-JobProgress -Id $id -Now (Get-Date))
    return
  }

  if ($method -eq 'POST' -and $path -eq '/api/job/stop') {
    $id = $q['job']
    if (-not $id) { Send-Json $Client 400 @{ error = 'missing job' }; return }
    $job = $script:Jobs[$id]
    if (-not $job) { Send-Json $Client 404 @{ error = 'job not found' }; return }
    try {
      if ($job.Process.HasExited) { Send-Json $Client 200 @{ ok = $true; alreadyExited = $true }; return }
      # 先尝试 taskkill 杀掉整个进程树 (cmd -> powershell -> npm)，失败再尝试直接结束子进程
      & taskkill.exe /PID $job.Process.Id /T /F 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Stop-Process -Id $job.Process.Id -Force -ErrorAction SilentlyContinue
      }
      Send-Json $Client 200 @{ ok = $true }
    } catch { Send-Json $Client 500 @{ error = $_.Exception.Message } }
    return
  }

  if ($method -eq 'POST' -and $path -eq '/api/install') {
    $id = 'job-' + [guid]::NewGuid().ToString('N')
    $argsLine = ' -NoPrompts'
    if ($q['registry']) { $argsLine += ' -Registry "' + $q['registry'] + '"' }
    if ($q['system']) { $argsLine += ' -UseSystemNode' }
    if ($q['pnpm']) { $argsLine += ' -Pnpm' }
    if ($q['nodeVersion']) { $argsLine += ' -NodeVersion "' + $q['nodeVersion'] + '"' }
    Start-RunJob -Id $id -ScriptPath (Join-Path $PSScriptRoot 'install.ps1') -ArgsLine $argsLine -Label '安装'
    Send-Json $Client 200 @{ job = $id }
    return
  }
  if ($method -eq 'POST' -and $path -eq '/api/update') {
    $id = 'job-' + [guid]::NewGuid().ToString('N')
    $argsLine = ''
    if ($q['registry']) { $argsLine += ' -Registry "' + $q['registry'] + '"' }
    Start-RunJob -Id $id -ScriptPath (Join-Path $PSScriptRoot 'update.ps1') -ArgsLine $argsLine -Label '升级'
    Send-Json $Client 200 @{ job = $id }
    return
  }
  if ($method -eq 'POST' -and $path -eq '/api/uninstall') {
    $id = 'job-' + [guid]::NewGuid().ToString('N')
    Start-RunJob -Id $id -ScriptPath (Join-Path $PSScriptRoot 'uninstall.ps1') -ArgsLine ' -Yes' -Label '卸载'
    Send-Json $Client 200 @{ job = $id }
    return
  }

  if ($method -eq 'POST' -and $path -eq '/api/web/start') {
    $port = 3080
    if ($q['port']) { [int]::TryParse($q['port'], [ref]$port) | Out-Null }
    if (-not (Get-DshBin)) {
      # 未安装 dsh -> 先自动安装，页面在安装成功后会自动再次调用本接口启动 Web UI
      $id = 'job-' + [guid]::NewGuid().ToString('N')
      Start-RunJob -Id $id -ScriptPath (Join-Path $PSScriptRoot 'install.ps1') -ArgsLine ' -NoPrompts' -Label '自动安装(为启动 Web UI)'
      Send-Json $Client 200 @{ ok = $false; needInstall = $true; job = $id; port = $port }
      return
    }
    # 若指定端口被占用，自动换一个空闲端口，避免启动失败
    if (Test-LocalPort $port) {
      $candidates = @()
      for ($p = 3080; $p -le 3120; $p++) { $candidates += $p }
      $free = $candidates | Where-Object { -not (Test-LocalPort $_) } | Select-Object -First 1
      if (-not $free) {
        $free = Get-Random -Minimum 40000 -Maximum 50000
        while (Test-LocalPort $free) { $free = Get-Random -Minimum 40000 -Maximum 50000 }
      }
      Write-Host ("[面板] 端口 $port 被占用，自动改用 $free")
      $port = $free
    }
    $startWeb = Join-Path $PSScriptRoot 'start-web.ps1'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $startWeb + '"'))
    if ($port -ne 3080) { $argList += '--port'; $argList += [string]$port }
    try {
      Start-Process powershell -ArgumentList $argList -WorkingDirectory $Root
      Send-Json $Client 200 @{ ok = $true; port = $port }
    } catch { Send-Json $Client 500 @{ error = $_.Exception.Message } }
    return
  }
  if ($method -eq 'POST' -and $path -eq '/api/dsh') {
    try { Start-Process (Join-Path $Root 'dsh.cmd') -WorkingDirectory $Root; Send-Json $Client 200 @{ ok = $true } }
    catch { Send-Json $Client 500 @{ error = $_.Exception.Message } }
    return
  }
  if ($method -eq 'POST' -and $path -eq '/api/open') {
    $rel = $q['path']
    if (-not $rel) { Send-Json $Client 400 @{ error = 'missing path' }; return }
    $target = Join-Path $Root $rel
    try {
      if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
      Start-Process explorer.exe -ArgumentList ('"' + $target + '"')
      Send-Json $Client 200 @{ ok = $true }
    } catch { Send-Json $Client 500 @{ error = $_.Exception.Message } }
    return
  }

  Send-Json $Client 404 @{ error = 'not found: ' + $method + ' ' + $path }
}

# ---------------- 启动 ----------------
if ($Port -gt 0) { $script:Port = $Port }
else {
  $script:Port = 38765
  $tries = 0
  while ((Test-LocalPort $script:Port) -and $tries -lt 30) {
    $script:Port = Get-Random -Minimum 40000 -Maximum 50000
    $tries++
  }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $script:Port)
$listener.Start()

$url = 'http://127.0.0.1:' + $script:Port + '/'
Write-Host ''
Write-Host '======================================================' -ForegroundColor Cyan
Write-Host '  DeepSeek Harness 控制面板' -ForegroundColor Cyan
Write-Host ("  地址: " + $url) -ForegroundColor Cyan
Write-Host '  仅本机可访问。关闭本窗口或按 Ctrl+C 停止面板服务。' -ForegroundColor Cyan
Write-Host '======================================================' -ForegroundColor Cyan
Write-Host ''

if (-not $NoBrowser) {
  try { Start-Process $url } catch {}
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try { Handle-Request $client } catch { Write-Host ("[面板] 请求处理异常: " + $_.Exception.Message) } finally { $client.Close() }
  }
} finally {
  $listener.Stop()
}
