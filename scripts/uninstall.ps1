# uninstall.ps1 - 卸载并删除整个便携目录（含用户数据）
param([switch]$Yes)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host '======================================================' -ForegroundColor Yellow
Write-Host ('即将删除整个目录: ' + $Root) -ForegroundColor Yellow
Write-Host '包括: 便携 Node (tools)、DeepSeek Harness 程序、用户数据 (data\dsh)。' -ForegroundColor Yellow
Write-Host '此操作不可恢复! 请先关闭 启动Web界面 / dsh 命令行 窗口。' -ForegroundColor Yellow
Write-Host '======================================================' -ForegroundColor Yellow

if (-not $Yes) {
  $ans = Read-Host '确认删除? (y/N)'
  if ($ans -notmatch '^[yY]') { Write-Host '已取消。'; exit 0 }
}

Write-Info '[DSH-PROG] start:uninstall'
$tmp = Join-Path $env:TEMP ('dsh-uninstall-' + [guid]::NewGuid().ToString('N') + '.cmd')
$body = '@echo off' + "`r`n" +
        'ping 127.0.0.1 -n 4 >nul' + "`r`n" +
        ('rmdir /s /q "' + $Root + '"') + "`r`n" +
        'del /q "%~f0"' + "`r`n"
[System.IO.File]::WriteAllText($tmp, $body, [System.Text.Encoding]::ASCII)
Start-Process cmd.exe -ArgumentList @('/c', ('"' + $tmp + '"')) -WindowStyle Hidden
Write-Info '[DSH-PROG] end:uninstall'
Write-Host '删除任务已启动，本窗口即将关闭。' -ForegroundColor Green
Start-Sleep -Milliseconds 800
exit 0
