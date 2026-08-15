# start-web.ps1 - 启动 DeepSeek Harness Web UI
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-web.ps1 [--port 8080] [--host 127.0.0.1]
param()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

$dshBin = Get-DshBin
if (-not $dshBin) {
  Write-Host '尚未安装 DeepSeek Harness，正在自动安装（如想自定义 npm 源/便携版等选项，可先运行 开始安装.cmd）...' -ForegroundColor Yellow
  $install = Join-Path $PSScriptRoot 'install.ps1'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $install -NoPrompts
  if ($LASTEXITCODE -ne 0) {
    Write-Err '自动安装失败。请检查网络/代理（或运行 开始安装.cmd 手动安装），然后重试。'
    exit 1
  }
  $dshBin = Get-DshBin
  if (-not $dshBin) { Write-Err 'DeepSeek Harness 仍未就绪，请运行 开始安装.cmd 检查。'; exit 1 }
  Write-Host '安装完成，正在启动 Web UI...' -ForegroundColor Green
}
if ($dshBin -ne 'dsh') { $env:PATH = "$NodeDir;$env:PATH" }

# 解析 --port 用于构造访问地址
$port = 3080
$rest = @()
$i = 0
while ($i -lt $args.Count) {
  if ($args[$i] -eq '--port' -and ($i + 1) -lt $args.Count) {
    $port = $args[$i + 1]
    $rest += '--port'; $rest += $args[$i + 1]
    $i += 2
    continue
  }
  $rest += $args[$i]
  $i++
}
$url = "http://127.0.0.1:$port"

Write-Host '======================================================' -ForegroundColor Cyan
Write-Host '  DeepSeek Harness Web UI' -ForegroundColor Cyan
Write-Host ("  地址: $url    (按 Ctrl+C 停止服务)") -ForegroundColor Cyan
Write-Host '  浏览器将自动打开；若未打开请手动访问。' -ForegroundColor Cyan
Write-Host '======================================================' -ForegroundColor Cyan

# 后台等待服务就绪后自动打开浏览器
New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
$opener = Join-Path $ToolsDir 'open-browser.ps1'
@"
`$url = '$url'
`$ok = `$false
for (`$i = 0; `$i -lt 90; `$i++) {
  try {
    `$r = Invoke-WebRequest -UseBasicParsing -Uri `$url -TimeoutSec 2
    if (`$r.StatusCode -ge 200) { `$ok = `$true; break }
  } catch {}
  Start-Sleep -Seconds 1
}
if (`$ok) { Start-Process `$url }
"@ | Set-Content $opener -Encoding UTF8
Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $opener + '"')) -WindowStyle Hidden

& $dshBin web @rest
exit $LASTEXITCODE
