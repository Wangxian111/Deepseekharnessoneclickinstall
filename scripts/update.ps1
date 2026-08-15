# update.ps1 - 升级 DeepSeek Harness (dsh) 到最新版
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update.ps1 [-Registry https://...]
param([string]$Registry)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host '========== 升级 DeepSeek Harness (dsh) ==========' -ForegroundColor Magenta

if (Test-PortableNode) {
  $npmCmd = Join-Path $NodeDir 'npm.cmd'
  $env:PATH = "$NodeDir;$env:PATH"
  Write-Info ("使用便携 Node.js: " + (Get-PortableNodeVersion))
} else {
  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $npm) { Write-Err '未找到 Node/npm，请先运行 install.cmd'; exit 1 }
  $npmCmd = $npm.Source
  Write-Info ("使用系统 Node.js: " + (Get-SystemNodeInfo).Version)
}

$pkgBase = if ($env:DSH_NPM_PACKAGE) { $env:DSH_NPM_PACKAGE } else { '@deepseek-ai/dsh' }

$registries = @()
if ($Registry) { $registries += $Registry }
# npmmirror 优先（国内快），官方源对国内网络常常很慢
$registries += 'https://registry.npmmirror.com/', 'https://registry.npmjs.org/', 'https://repo.huaweicloud.com/repository/npm/'
$registries = $registries | Select-Object -Unique

$npmExtra = @('--fetch-timeout=30000', '--fetch-retries=1', '--progress=false', '--loglevel=http', '--no-audit', '--no-fund')

Write-Info '[DSH-PROG] start:npm'
$ok = $false
foreach ($reg in $registries) {
  Write-Info ("  使用源: $reg")
  & $npmCmd install -g $pkgBase --registry $reg @npmExtra
  if ($LASTEXITCODE -eq 0) { $ok = $true; break }
  Write-Warn ("  失败 (exit=$LASTEXITCODE)，尝试下一个源...")
}
if (-not $ok) { Write-Err '升级失败，请检查网络后重试'; exit 1 }
Write-Info '[DSH-PROG] end:npm'

Write-Info '[DSH-PROG] start:verify'
$dshBin = Get-DshBin
if ($dshBin) {
  try { Write-Info ("当前版本: " + ((& $dshBin --version 2>&1) -join ' ').Trim()) } catch {}
}
Write-Info '[DSH-PROG] end:verify'
Write-Host '升级完成。' -ForegroundColor Green
exit 0
