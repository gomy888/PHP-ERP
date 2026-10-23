<#
=====================================================================
 智美成ERP系统 绿色版 · php-cgi 看门狗
=====================================================================
 作用:
   php-cgi 进程意外退出时,nginx 会持续返回 502 Bad Gateway。
   本看门狗每 10 秒检查一次 FastCGI 端口段(CgiBasePort 起)的监听状态,
   发现某个端口失去监听就自动补拉起一个 php-cgi,保证全站可用。

 说明:
   - 连续多次拉起失败会放弃本轮(避免配置错误时疯狂重启)
   - 所有动作写入 runtime\logs\watchdog.log
   - 由 start.ps1 以脱离控制台方式启动,stop.ps1 会结束它
=====================================================================
#>
param(
    [int]$CgiWorkers = 4,
    [int]$CgiBasePort = 9000,
    [int]$Interval   = 5,
    [int]$MaxRetry   = 3
)

$ErrorActionPreference = 'SilentlyContinue'
$Root    = Split-Path -Parent $PSScriptRoot
$Runtime = Join-Path $Root 'runtime'
$PhpCgi  = Join-Path $Runtime 'php\php-cgi.exe'
$PhpIni  = Join-Path $Runtime 'php\php.ini'
$PhpExe  = Join-Path $Runtime 'php\php.exe'
$LogFile = Join-Path $Runtime 'logs\watchdog.log'
$StopFlag = Join-Path $Runtime 'logs\service.stopped'
$BackupScript = Join-Path $Root 'database\backup.php'

if (-not (Test-Path (Split-Path $LogFile))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
}

function Write-WatchLog($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# 依赖:spawn_detached.ps1 提供 Start-DetachedProcess
$spawnFile = Join-Path $Root 'bin\spawn_detached.ps1'
if (-not (Test-Path $spawnFile)) {
    Write-WatchLog "找不到 spawn_detached.ps1,看门狗退出"
    exit 1
}
. $spawnFile

# 只统计「本实例」的 php-cgi:按命令行里的 php.ini 路径精确匹配。
# (用 Get-Process 的 .Path 匹配不可靠:多套实例并存时容易互相误判,
#  甚至在进程刚退出时取不到路径而误判成「一个都没了」。)
function Get-OurCgiCount {
    $n = @(Get-CimInstance Win32_Process -Filter "Name = 'php-cgi.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*$PhpIni*" }).Count
    return $n
}

Write-WatchLog "看门狗启动(每 ${Interval}s 检查一次,进程池 $CgiWorkers,端口段 $CgiBasePort 起)"

$failCount = @{}
$poolRestarts = 0

# ── 定时备份 ──────────────────────────────────────────────
# 每 60 秒调用一次 database/backup.php,由脚本自己判断是否到点
# (依据 sys_config 的 backup.auto_time 与 backup.last_run)。
# 失败信息限流记录,避免日志被刷屏。
$nextBackupCheck = (Get-Date).AddSeconds(60)
$backupErrNext   = (Get-Date).AddMinutes(30)

function Invoke-BackupCheck {
    if (-not (Test-Path $PhpExe)) { return }
    if (-not (Test-Path $BackupScript)) { return }
    $out = & $PhpExe $BackupScript 2>&1
    $code = $LASTEXITCODE
    $line = ((($out | Out-String) -replace '\s+', ' ')).Trim()
    if ($code -eq 0) {
        if ($line.StartsWith('OK')) { Write-WatchLog "定时备份: $line" }
        return
    }
    if ((Get-Date) -ge $script:backupErrNext) {
        $script:backupErrNext = (Get-Date).AddMinutes(30)
        Write-WatchLog "定时备份执行失败(退出码 $code): $line"
    }
}

while ($true) {
    Start-Sleep -Seconds $Interval

    # 定时备份检查(每分钟一次)
    if ((Get-Date) -ge $nextBackupCheck) {
        $nextBackupCheck = (Get-Date).AddSeconds(60)
        Invoke-BackupCheck
    }

    # php-cgi 进程池一个都不剩时:
    #   有停止标记 = 用户执行了「停止系统」,看门狗退出;
    #   无停止标记 = 意外全挂,自动重建整个进程池,保证全站可用。
    $anyCgi = Get-OurCgiCount
    if ($anyCgi -eq 0) {
        if (Test-Path $StopFlag) {
            Write-WatchLog "未发现任何 php-cgi 进程,检测到停止标记,判定服务已停止,看门狗退出"
            exit 0
        }
        $poolRestarts++
        if ($poolRestarts -gt 10) {
            Write-WatchLog "进程池已连续重建 $poolRestarts 次仍无存活,暂停重建并退出"
            exit 0
        }
        Write-WatchLog "未发现任何 php-cgi 进程(非正常停止),第 $poolRestarts 次自动重建进程池"
        for ($i = 0; $i -lt $CgiWorkers; $i++) {
            $port = $CgiBasePort + $i
            try {
                $p = Start-DetachedProcess -FilePath $PhpCgi `
                     -ArgumentList ('-c "' + $PhpIni + '" -b 127.0.0.1:' + $port) `
                     -WorkingDirectory (Join-Path $Runtime 'php')
                if ($p -gt 0) {
                    Write-WatchLog "php-cgi 已在端口 $port 重建 (PID $p)"
                }
            } catch {
                Write-WatchLog "php-cgi 在端口 $port 重建失败: $($_.Exception.Message)"
            }
        }
        Start-Sleep -Seconds 5
        $anyCgi = Get-OurCgiCount
        if ($anyCgi -gt 0) {
            $poolRestarts = 0
        }
        continue
    }
    $poolRestarts = 0

    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $port = $CgiBasePort + $i
        $listening = $false
        try {
            $listening = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) -ne $null
        } catch { }

        if ($listening) {
            if ($failCount.ContainsKey($port)) { $failCount.Remove($port) }
            continue
        }

        # 端口没监听:先确认是不是还有孤儿进程占着
        $owner = Get-OurCgiCount
        $portBusy = $false
        try {
            $portBusy = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) -ne $null
        } catch { }
        if ($portBusy) { continue }

        $key = [string]$port
        $n = 0
        if ($failCount.ContainsKey($key)) { $n = $failCount[$key] }
        if ($n -ge $MaxRetry) {
            continue
        }

        Write-WatchLog "端口 $port 失去监听,尝试补拉 php-cgi(第 $($n+1) 次)"
        try {
            # 旧进程的监听套接字可能还没释放,稍等一下再拉,避免 "Address already in use"
            Start-Sleep -Milliseconds 400
            $p = Start-DetachedProcess -FilePath $PhpCgi `
                 -ArgumentList ('-c "' + $PhpIni + '" -b 127.0.0.1:' + $port) `
                 -WorkingDirectory (Join-Path $Runtime 'php')
            if ($p -gt 0) {
                # 确认新进程真的监听起来,没监听起来算失败,下一轮继续重试
                $up = $false
                for ($t = 0; $t -lt 15; $t++) {
                    Start-Sleep -Milliseconds 200
                    try {
                        $up = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) -ne $null
                    } catch { }
                    if ($up) { break }
                }
                if ($up) {
                    $failCount[$key] = 0
                    Write-WatchLog "php-cgi 已在端口 $port 补拉成功 (PID $p)"
                } else {
                    $failCount[$key] = $n + 1
                    Write-WatchLog "php-cgi 在端口 $port 补拉后未监听 (PID $p)"
                }
            } else {
                $failCount[$key] = $n + 1
                Write-WatchLog "php-cgi 在端口 $port 补拉失败"
            }
        } catch {
            $failCount[$key] = $n + 1
            Write-WatchLog "php-cgi 在端口 $port 补拉异常: $($_.Exception.Message)"
        }
    }
}
