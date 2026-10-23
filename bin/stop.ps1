<#
=====================================================================
 智美成ERP系统 绿色版 · 停止脚本
=====================================================================
#>
$ErrorActionPreference = 'SilentlyContinue'
$Root    = Split-Path -Parent $PSScriptRoot
$Runtime = Join-Path $Root 'runtime'

function Write-Step($msg) { Write-Host "  [>] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "  正在停止 智美成ERP系统 ..." -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------"

# 打上停止标记:看门狗据此区分「用户主动停止」与「php-cgi 意外全挂」
$stopFlag = Join-Path $Runtime 'logs\service.stopped'
try {
    if (-not (Test-Path (Split-Path $stopFlag))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $stopFlag) | Out-Null
    }
    Set-Content -Path $stopFlag -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
} catch { }

# --- 看门狗(须最先停,否则它会把刚停掉的 php-cgi 再拉起来) ---
$watchdogPid = Join-Path $Runtime 'watchdog.pid'
if (Test-Path $watchdogPid) {
    $id = [int](Get-Content $watchdogPid -Raw).Trim()
    if ($id -gt 0) {
        $p = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Id $id -Force; Write-Ok "看门狗已停止 (PID $id)" }
    }
    Remove-Item $watchdogPid -Force -ErrorAction SilentlyContinue
}
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*$Root\bin\watchdog.ps1*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Write-Ok "已清理残留看门狗 (PID $($_.ProcessId))" }

# --- nginx ---
$nginxExe = Join-Path $Runtime 'nginx\nginx.exe'
if (Test-Path $nginxExe) {
    $nginxDir = Join-Path $Runtime 'nginx'
    Push-Location $nginxDir
    & $nginxExe -p "$nginxDir/" -c conf/nginx.conf -s stop 2>$null | Out-Null
    Pop-Location
    Start-Sleep -Milliseconds 800
}
Get-Process nginx -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Root\runtime\nginx*" } |
    ForEach-Object { Stop-Process -Id $_.Id -Force; Write-Ok "已停止 nginx (PID $($_.Id))" }

# 安装目录含中文时,nginx / php-cgi 是通过 %TEMP% 下的 ASCII 目录联接启动的,
# 上面按路径匹配不到,这里再按「命令行里含本目录的 runtime 子目录或别名」兜底清理。
# 注意:必须匹配 <根目录>\runtime\,否则加密版(位于源码版目录内部)的进程会被误杀。
$aliasDir = $null
try {
    . (Join-Path $Root 'bin\ascii_alias.ps1')
    $aliasDir = Get-ZmcAliasPath -Root $Root
} catch { }
$rootMark = $Root.TrimEnd('\') + '\runtime\'
$aliasMark = ''
if ($aliasDir) { $aliasMark = $aliasDir.TrimEnd('\') + '\runtime\' }
Get-CimInstance Win32_Process -Filter "Name = 'nginx.exe' or Name = 'php-cgi.exe' or Name = 'mysqld.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
        if (-not $_.CommandLine) { return $false }
        $cl = $_.CommandLine.Replace('/', '\')
        if ($cl -like "*$rootMark*") { return $true }
        if ($aliasMark -and $cl -like "*$aliasMark*") { return $true }
        return $false
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Ok "已停止残留进程 $($_.Name) (PID $($_.ProcessId))"
    }

# --- php-cgi 进程池 ---
$cgiPidFile = Join-Path $Runtime 'php-cgi.pids'
if (Test-Path $cgiPidFile) {
    foreach ($line in (Get-Content $cgiPidFile)) {
        $id = [int]$line.Trim()
        if ($id -gt 0) {
            $p = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($p) { Stop-Process -Id $id -Force; Write-Ok "已停止 php-cgi (PID $id)" }
        }
    }
    Remove-Item $cgiPidFile -Force -ErrorAction SilentlyContinue
}
# 兜底:按路径清理所有属于本项目的 php-cgi
Get-Process php-cgi -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Root\runtime\php*" } |
    ForEach-Object { Stop-Process -Id $_.Id -Force; Write-Ok "已清理残留 php-cgi (PID $($_.Id))" }

# --- PHP 内置服务器 ---
$phpPid = Join-Path $Runtime 'php-server.pid'
if (Test-Path $phpPid) {
    $id = [int](Get-Content $phpPid -Raw).Trim()
    if ($id -gt 0) {
        $p = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Id $id -Force; Write-Ok "Web 服务已停止 (PID $id)" }
    }
    Remove-Item $phpPid -Force -ErrorAction SilentlyContinue
}
Get-Process php -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Root\runtime\php*" } |
    ForEach-Object { Stop-Process -Id $_.Id -Force; Write-Ok "已清理残留 PHP 进程 (PID $($_.Id))" }

# --- MySQL(仅停止本项目实例) ---
$myPid = Join-Path $Runtime 'mysqld.pid'
if (Test-Path $myPid) {
    $id = [int](Get-Content $myPid -Raw).Trim()
    if ($id -gt 0) {
        $p = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($p -and $p.Path -like "$Root*") {
            Stop-Process -Id $id -Force
            Write-Ok "数据库服务已停止 (PID $id)"
        }
    }
    Remove-Item $myPid -Force -ErrorAction SilentlyContinue
}
Get-Process mysqld -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$Root\runtime\mysql*" } |
    ForEach-Object { Stop-Process -Id $_.Id -Force; Write-Ok "已清理残留 mysqld (PID $($_.Id))" }

Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  已全部停止。" -ForegroundColor Green
Write-Host ""
