<#
=====================================================================
 智美成ERP系统 绿色版 · 数据库初始化 / 重建
   用法: powershell -File bin\setup.ps1 [-Fresh] [-SkipPasswordCheck]

   -Fresh            重建数据库(清空全部业务数据)
   -SkipPasswordCheck  跳过管理员口令校验(仅在管理员密码确实丢失时使用)
=====================================================================
#>
param(
    [switch]$Fresh,
    [int]$DbPort   = 3309,
    [string]$AdminUser = 'admin',
    [switch]$SkipPasswordCheck
)

$ErrorActionPreference = 'Stop'
$Root    = Split-Path -Parent $PSScriptRoot
$Runtime = Join-Path $Root 'runtime'
$PhpExe  = Join-Path $Runtime 'php\php.exe'
$MySqlC  = Join-Path $Runtime 'mysql\bin\mysql.exe'
$MySqlD  = Join-Path $Runtime 'mysql\bin\mysqld.exe'

function Write-Step($msg) { Write-Host "  [>] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------- 口令输入
# 交互式:Read-Host -AsSecureString 掩码输入,屏幕上只显示 * ,不回显明文
# 重定向式(stdin 被重定向):Read-Host 在 PS 5.1 下会永远阻塞,
#         这种情况直接读一行(此时口令本来就不在屏幕上,无需掩码)
function Read-Secret([string]$Prompt) {
    Write-Host -NoNewline $Prompt -ForegroundColor White
    if ([Console]::IsInputRedirected) {
        $line = [Console]::In.ReadLine()
        Write-Host ""
        if ($null -eq $line) { return '' }
        return $line.Trim()
    }
    $sec = Read-Host -AsSecureString
    Write-Host ""
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# ---------------------------------------------------------------- 口令核验
# 调用 database\check_admin_password.php 校验;口令走标准输入,不进命令行参数
function Test-AdminPassword([string]$Password, [string]$User) {
    $script = Join-Path $Root 'database\check_admin_password.php'
    if (-not (Test-Path -LiteralPath $script)) { return 'ERR:helper-missing' }
    $out = @($Password | & $PhpExe $script $User 2>&1)
    if ($out.Count -eq 0) { return 'ERR:no-output' }
    return (($out | Select-Object -Last 1) | Out-String).Trim()
}

Write-Host ""
Write-Step "确保数据库服务运行..."
$ready = $false
try {
    $null = & $MySqlC -h 127.0.0.1 -P $DbPort -u root --connect-timeout=2 -N -e "SELECT 1;" 2>$null
    if ($LASTEXITCODE -eq 0) { $ready = $true }
} catch { }

if (-not $ready) {
    $myIni = Join-Path $Runtime 'mysql\my.ini'
    if (-not (Test-Path $myIni)) { Write-Err "缺少 my.ini,请先运行一次「启动系统.bat」"; exit 1 }
    . (Join-Path $Root 'bin\spawn_detached.ps1')
    $proc = Start-DetachedProcess -FilePath $MySqlD `
         -ArgumentList ('--defaults-file="' + $myIni + '"') `
         -WorkingDirectory (Join-Path $Runtime 'mysql')
    Set-Content -Path "$Runtime\mysqld.pid" -Value $proc -Encoding ASCII
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $null = & $MySqlC -h 127.0.0.1 -P $DbPort -u root --connect-timeout=2 -N -e "SELECT 1;" 2>$null
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        } catch { }
    }
}
if (-not $ready) { Write-Err "数据库服务未启动"; exit 1 }
Write-Ok "数据库服务运行中"

# ---------------------------------------------------------------- 危险操作二次确认
# 重建数据库会清空全部业务数据。除了批处理里的 Y 确认之外,
# 这里再要求「输入两次管理员密码」,防止误触。
if ($Fresh -and -not $SkipPasswordCheck) {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Red
    Write-Host "   危 险 操 作 : 即将重建数据库,全部业务数据将被清空" -ForegroundColor Red
    Write-Host "  ============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "   请输入管理员账号 " -NoNewline -ForegroundColor Yellow
    Write-Host $AdminUser -NoNewline -ForegroundColor White
    Write-Host " 的登录密码,并连输两次。" -ForegroundColor Yellow
    Write-Host ""

    $pw1 = Read-Secret "   第 1 次输入密码: "
    if ([string]::IsNullOrEmpty($pw1)) {
        Write-Err "未输入密码,操作已取消"
        exit 1
    }
    $pw2 = Read-Secret "   第 2 次输入密码: "
    if ($pw1 -ne $pw2) {
        $pw1 = $null; $pw2 = $null
        Write-Err "两次输入的密码不一致,操作已取消"
        exit 1
    }

    $env:ERP_DB_PORT = "$DbPort"
    $verdict = Test-AdminPassword $pw1 $AdminUser
    $pw1 = $null; $pw2 = $null

    switch -Regex ($verdict) {
        '^OK$' {
            Write-Ok "管理员口令校验通过"
        }
        '^NOADMIN$' {
            Write-Host "  [提示] 库里还没有管理员账号(数据库本来就是空的),没有数据可清空,继续。" -ForegroundColor Yellow
        }
        '^BAD$' {
            Write-Err "管理员密码不正确,操作已取消"
            exit 1
        }
        default {
            Write-Err "无法校验管理员密码($verdict),为安全起见操作已取消"
            Write-Err "如果管理员密码确实丢失,可执行:"
            Write-Err "    powershell -NoProfile -ExecutionPolicy Bypass -File bin\setup.ps1 -Fresh -SkipPasswordCheck"
            exit 1
        }
    }
}

Write-Step "执行安装脚本..."
$args = @("$Root\database\install.php")
if ($Fresh) { $args += '--fresh' }
& $PhpExe @args
if ($LASTEXITCODE -ne 0) { Write-Err "安装失败"; exit 1 }

Write-Ok "完成"
Write-Host ""
