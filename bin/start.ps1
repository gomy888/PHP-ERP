<#
=====================================================================
 智美成ERP系统 绿色版 · 启动脚本
   1. 生成本机绝对路径的 php.ini / my.ini / nginx.conf(无 BOM)
   2. 启动内置 MySQL(免安装,独立端口 3307)
   3. 首次运行自动建库建表并写入种子数据
   4. 启动 Web 服务
        优先 nginx + php-cgi(真正的多进程并发,适合多人同时在线)
        若缺少 nginx 则退回 PHP 内置服务器(单进程,仅供单机演示)
   5. 自动打开浏览器
=====================================================================
#>
param(
    [int]$HttpPort = 8090,
    [int]$DbPort   = 3309,
    [int]$CgiWorkers = 8,
    [int]$CgiBasePort = 9010,
    [switch]$NoBrowser,
    [switch]$BuiltinOnly
)

$ErrorActionPreference = 'Stop'
$Root    = Split-Path -Parent $PSScriptRoot
$Runtime = Join-Path $Root 'runtime'
$PhpExe  = Join-Path $Runtime 'php\php.exe'
$PhpCgi  = Join-Path $Runtime 'php\php-cgi.exe'
$MySqlD  = Join-Path $Runtime 'mysql\bin\mysqld.exe'
$MySqlC  = Join-Path $Runtime 'mysql\bin\mysql.exe'
$NginxExe = Join-Path $Runtime 'nginx\nginx.exe'
$ConfTpl = Join-Path $Root 'config\nginx.conf.template'

function Write-Step($msg) { Write-Host "  [>] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "  [!!] $msg" -ForegroundColor Red }

# 写文件时必须不带 BOM,否则 nginx / MySQL 解析配置会报错
function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# php.ini / my.ini 的编码要求正好相反:
#   - php.ini 由 PHP 自己解析,内部按 UTF-8 处理路径 → 必须写 UTF-8
#   - my.ini 由 MySQL 解析,按「系统 ANSI 代码页」读取 → 含中文路径时必须写 ANSI(GBK),
#     否则 MySQL 会报 "Can't create directory"。
# 两者都不能带 BOM。
function Write-PhpIni([string]$Path, [string]$Content) {
    Write-Utf8NoBom $Path $Content
}

function Write-MyIni([string]$Path, [string]$Content) {
    if ($Content -match '[^\x00-\x7F]') {
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::Default)
    } else {
        Write-Utf8NoBom $Path $Content
    }
}

Write-Host ""
Write-Host "  正在启动 智美成ERP系统 绿色版 ..." -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------"

# 清除停止标记(本进程启动即代表服务处于运行态)
try { Remove-Item (Join-Path $Runtime 'logs\service.stopped') -Force -ErrorAction SilentlyContinue } catch { }

# ---------------------------------------------------------------- 1. 配置
Write-Step "生成运行配置..."
$forward = $Root.Replace('\', '/')
$phpIni = Join-Path $Runtime 'php\php.ini'
$myIni  = Join-Path $Runtime 'mysql\my.ini'

# ── 非 ASCII 路径的统一处理 ─────────────────────────────────────────
# Windows 上有两处必须用纯 ASCII 路径:
#   1) nginx      —— 含中文会报 1113 (No mapping for the Unicode character)
#   2) PHP 扩展   —— extension_dir 最终走 LoadLibraryExA(ANSI 路径),
#                     含中文时所有扩展都加载不了
# 因此当安装目录含中文(如 ERP加密版)时,建立一个指向本目录的 ASCII 目录联接,
# 让 nginx 和 PHP 都用 ASCII 路径工作(只是指针,不复制任何文件,删掉也不影响数据)。
. (Join-Path $Root 'bin\ascii_alias.ps1')

$aliasDir = Initialize-ZmcAsciiAlias -Root $Root
$nginxRoot = $Root
if ($aliasDir -and $aliasDir -ne $Root) {
    $nginxRoot = $aliasDir
    Write-Ok "安装目录含中文,已建立 ASCII 路径别名: $aliasDir"
} elseif (-not $aliasDir) {
    Write-Err "建立 ASCII 路径别名失败(nginx 与 PHP 扩展可能无法正常工作)"
}
$nginxForward = $nginxRoot.Replace('\', '/')

# PHP 的 extension_dir 必须是纯 ASCII 路径
$extDir = "$forward/runtime/php/ext"
if (Test-ZmcNonAscii $extDir) {
    $extAlias = $null
    if ($aliasDir) { $extAlias = Join-Path $aliasDir 'runtime\php\ext' }
    if (-not $extAlias) {
        # 兜底:给 ext 目录单独建一个 ASCII 联接
        $sub = Initialize-ZmcAsciiAliasFor -Root $Root -SubPath (Join-Path $Root 'runtime\php\ext')
        if ($sub) { $extAlias = $sub }
    }
    if ($extAlias) {
        $extDir = $extAlias.Replace('\', '/')
        Write-Ok "PHP 扩展目录已切换到 ASCII 路径: $extDir"
    } else {
        Write-Err "PHP 扩展目录无法转为 ASCII 路径,扩展可能加载失败"
    }
}

# 让 php-cgi / 安装脚本 / 命令行工具都知道本次使用的数据库端口
# (默认 3307;用 -DbPort 改了端口时必须同步,否则应用会连到别的实例)
$env:ERP_DB_PORT = "$DbPort"
$env:ERP_DB_HOST = '127.0.0.1'

$phpIniTpl = @"
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
serialize_precision = -1
max_execution_time = 120
max_input_vars = 5000
memory_limit = 256M
error_reporting = E_ALL
display_errors = On
display_startup_errors = On
log_errors = On
error_log = "$forward/runtime/logs/php-error.log"
date.timezone = Asia/Shanghai
default_charset = "UTF-8"
extension_dir = "$extDir"
extension=php_mbstring.dll
extension=php_openssl.dll
extension=php_pdo_mysql.dll
extension=php_mysqli.dll
extension=php_fileinfo.dll
extension=php_curl.dll
extension=php_zip.dll
extension=php_intl.dll
extension=php_sodium.dll
[Session]
session.save_handler = files
session.save_path = "$forward/runtime/tmp"
session.use_strict_mode = 1
session.use_cookies = 1
session.cookie_httponly = 1
session.gc_maxlifetime = 7200
session.gc_probability = 1
session.gc_divisor = 100
[opcache]
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 128
opcache.max_accelerated_files = 4000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
"@
Write-PhpIni $phpIni $phpIniTpl

$myIniTpl = @"
[mysqld]
basedir = $forward/runtime/mysql
datadir = $forward/runtime/data
port = $DbPort
bind-address = 127.0.0.1
pid-file = $forward/runtime/mysqld.pid
log-error = $forward/runtime/logs/mysqld-error.log
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
default-storage-engine = InnoDB
default-time-zone = '+08:00'
max_connections = 300
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_lock_wait_timeout = 15
lower_case_table_names = 1
sql_mode = STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION
[client]
port = $DbPort
default-character-set = utf8mb4
"@
Write-MyIni $myIni $myIniTpl

foreach ($d in @("$Runtime\data", "$Runtime\logs", "$Runtime\tmp", "$Root\storage\logs", "$Root\storage\backup")) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
Write-Ok "运行配置已就绪"

# ---------------------------------------------------------------- 2. MySQL
Write-Step "启动数据库服务(MySQL 端口 $DbPort)..."
$mysqlReady = $false
try {
    $null = & $MySqlC -h 127.0.0.1 -P $DbPort -u root --connect-timeout=2 -N -e "SELECT 1;" 2>$null
    if ($LASTEXITCODE -eq 0) { $mysqlReady = $true }
} catch { }

if (-not $mysqlReady) {
    if (-not (Test-Path "$Runtime\data\mysql")) {
        Write-Step "首次运行,初始化数据库文件..."
        & $MySqlD --defaults-file="$myIni" --initialize-insecure 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Err "MySQL 初始化失败"; exit 1 }
    }
    # 启动 mysqld(脱离控制台,启动器窗口关闭后数据库继续运行)
    . (Join-Path $Root 'bin\spawn_detached.ps1')
    $proc = Start-DetachedProcess -FilePath $MySqlD `
         -ArgumentList ('--defaults-file="' + $myIni + '"') `
         -WorkingDirectory (Join-Path $Runtime 'mysql')
    Set-Content -Path "$Runtime\mysqld.pid" -Value $proc -Encoding ASCII
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $null = & $MySqlC -h 127.0.0.1 -P $DbPort -u root --connect-timeout=2 -N -e "SELECT 1;" 2>$null
            if ($LASTEXITCODE -eq 0) { $mysqlReady = $true; break }
        } catch { }
    }
    if (-not $mysqlReady) {
        Write-Err "MySQL 启动失败,请查看 runtime\logs\mysqld-error.log"
        exit 1
    }
    Write-Ok "数据库服务已启动"
} else {
    Write-Ok "数据库服务已在运行"
}

# ---------------------------------------------------------------- 3. 账号
Write-Step "检查数据库账号..."
try {
    $sql = "CREATE USER IF NOT EXISTS 'erp'@'%' IDENTIFIED BY 'erp_dev_2024';"
    $sql += "CREATE USER IF NOT EXISTS 'erp'@'127.0.0.1' IDENTIFIED BY 'erp_dev_2024';"
    $sql += "GRANT ALL PRIVILEGES ON erp_php.* TO 'erp'@'%';"
    $sql += "GRANT ALL PRIVILEGES ON erp_php.* TO 'erp'@'127.0.0.1';"
    $sql += "FLUSH PRIVILEGES;"
    # 注意:不能写成 mysql -e "source <文件>" —— mysql 客户端按 ANSI 路径读文件,
    # 安装目录含中文时会失败。这里直接用标准输入喂给客户端。
    $sql | & $MySqlC -h 127.0.0.1 -P $DbPort -u root --default-character-set=utf8mb4 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "账号检查失败(继续尝试)" }
    else { Write-Ok "数据库账号就绪" }
} catch { Write-Err "账号检查失败(继续尝试): $($_.Exception.Message)" }

# ---------------------------------------------------------------- 4. 初始化
Write-Step "检查数据表..."
$needInstall = $true
try {
    $t = & $MySqlC -h 127.0.0.1 -P $DbPort -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='erp_php' AND table_name='sys_user';" 2>$null
    if ($LASTEXITCODE -eq 0 -and [int]$t -gt 0) { $needInstall = $false }
} catch { }

if ($needInstall) {
    Write-Step "初始化数据库(建表 + 权限 + 种子数据)..."
    & $PhpExe "$Root\database\install.php"
    if ($LASTEXITCODE -ne 0) { Write-Err "数据库初始化失败"; exit 1 }
    Write-Ok "数据库初始化完成"
} else {
    Write-Ok "数据表已存在,跳过初始化"
}

# ---------------------------------------------------------------- 5. Web
$portBusy = Get-NetTCPConnection -State Listen -LocalPort $HttpPort -ErrorAction SilentlyContinue
if ($portBusy) {
    Write-Err "端口 $HttpPort 已被占用,请先运行「停止系统.bat」或更换端口。"
    exit 1
}

$useNginx = (-not $BuiltinOnly) -and (Test-Path $NginxExe) -and (Test-Path $PhpCgi) -and (Test-Path $ConfTpl)

if ($useNginx) {
    Write-Step "启动 Web 服务(nginx + php-cgi,并发模式)..."

    # 生成 nginx 配置
    # max_fails=0:单个 php-cgi 偶发退出时不把它永久踢出池(配合 fastcgi_next_upstream 自动重试)
    $upstream = ""
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $upstream += "        server 127.0.0.1:" + ($CgiBasePort + $i) + " max_fails=0 fail_timeout=5s;`n"
    }
    $tpl = [System.IO.File]::ReadAllText($ConfTpl, [System.Text.Encoding]::UTF8)
    $conf = $tpl.Replace('__ROOT__', $nginxForward).Replace('__PORT__', "$HttpPort").Replace('__FCGI_UPSTREAM__', $upstream.TrimEnd())
    $nginxDir = Join-Path $nginxRoot 'runtime\nginx'
    foreach ($d in @("$nginxDir\logs", "$nginxDir\temp\client_body", "$nginxDir\temp\proxy", "$nginxDir\temp\fastcgi", "$nginxDir\temp\uwsgi", "$nginxDir\temp\scgi")) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    }
    Write-Utf8NoBom "$nginxDir\conf\nginx.conf" $conf

    # 启动 php-cgi 进程池
    # 关键:必须用 CreateProcess(DETACHED_PROCESS) 让 php-cgi 完全脱离启动器控制台,
    #       既不会继承 stdout 管道导致调用挂起,也不会在启动器窗口关闭时被连带回收。
    #
    # 先检查 FastCGI 端口段是否被占用:如果另一套实例(例如源码版和加密版)用了同一段端口,
    # nginx 会把请求随机转发到不属于本实例的 php-cgi 上,表现为
    # 「登录总是 419 / 会话丢失」这类极难排查的怪问题。这里直接拦下来。
    $cgiBusy = @()
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $p2 = $CgiBasePort + $i
        if (Get-NetTCPConnection -State Listen -LocalPort $p2 -ErrorAction SilentlyContinue) { $cgiBusy += $p2 }
    }
    if ($cgiBusy.Count -gt 0) {
        Write-Err "FastCGI 端口 $($cgiBusy -join ', ') 已被占用。"
        Write-Err "多半是另一套 ERP 实例还在运行(两套实例必须用不同的 FastCGI 端口段)。"
        Write-Err "请先运行「停止系统.bat」停掉占用者,或用 -CgiBasePort 指定别的端口段。"
        exit 1
    }

    . (Join-Path $Root 'bin\spawn_detached.ps1')
    $cgiPids = @()
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $port = $CgiBasePort + $i
        try {
            $p = Start-DetachedProcess -FilePath $PhpCgi `
                 -ArgumentList ('-c "' + $phpIni + '" -b 127.0.0.1:' + $port) `
                 -WorkingDirectory (Join-Path $Runtime 'php')
            $cgiPids += [int]$p
        } catch {
            Write-Err "php-cgi 端口 $port 启动失败: $($_.Exception.Message)"
        }
    }

    # 等待每个端口进入监听状态
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $port = $CgiBasePort + $i
        for ($t = 0; $t -lt 30; $t++) {
            Start-Sleep -Milliseconds 200
            if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { break }
        }
    }
    Start-Sleep -Milliseconds 400
    if ($cgiPids.Count -gt 0) {
        Set-Content -Path "$Runtime\php-cgi.pids" -Value ($cgiPids -join "`n") -Encoding ASCII
    } else {
        Write-Err "未找到 php-cgi 进程"
    }

    # 诊断:确认每个 php-cgi 是否存活并已监听
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        $port = $CgiBasePort + $i
        $listening = $false
        try {
            $listening = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) -ne $null
        } catch { }
        if (-not $listening) {
            Write-Err "php-cgi 端口 $port 未监听"
        }
    }

    # 启动 nginx(同样脱离控制台,启动器退出后仍常驻)
    try {
        $np = Start-DetachedProcess -FilePath $NginxExe `
             -ArgumentList ('-p "' + (($nginxRoot + '\runtime\nginx') -replace '\\', '/') + '/" -c conf/nginx.conf') `
             -WorkingDirectory (Join-Path $nginxRoot 'runtime\nginx')
        Set-Content -Path "$Runtime\nginx.pid" -Value $np -Encoding ASCII
    } catch {
        Write-Err "nginx 启动失败: $($_.Exception.Message)"
    }

    # 看门狗:php-cgi 意外退出时自动补拉,避免全站 502
    $watchdog = Join-Path $Root 'bin\watchdog.ps1'
    $psExe = Join-Path $PSHOME 'powershell.exe'
    if ((Test-Path $watchdog) -and (Test-Path $psExe)) {
        try {
            $wp = Start-DetachedProcess -FilePath $psExe `
                 -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $watchdog + '" -CgiWorkers ' + $CgiWorkers + ' -CgiBasePort ' + $CgiBasePort) `
                 -WorkingDirectory $Root -NoWindow
            Set-Content -Path "$Runtime\watchdog.pid" -Value $wp -Encoding ASCII
            Write-Step "看门狗已启动 (PID $wp)"
        } catch {
            Write-Err "看门狗启动失败: $($_.Exception.Message)"
        }
    }

    $mode = "nginx + $CgiWorkers 个 php-cgi 进程(并发)"
} else {
    Write-Step "启动 Web 服务(PHP 内置服务器,单进程模式)..."
    $env:PHP_CLI_SERVER_WORKERS = '4'
    $phpProc = Start-Process -FilePath $PhpExe `
        -ArgumentList "-S", "0.0.0.0:$HttpPort", "-t", "$Root\public", "$Root\public\router.php" `
        -WorkingDirectory $Root -WindowStyle Hidden -PassThru
    Set-Content -Path "$Runtime\php-server.pid" -Value $phpProc.Id -Encoding ASCII
    $mode = "PHP 内置服务器(单进程,仅单机演示)"
}

$webReady = $false
$webCode = 0
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 300
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$HttpPort/login")
        $req.AllowAutoRedirect = $false
        $req.Timeout = 3000
        $req.ReadWriteTimeout = 3000
        $resp = $req.GetResponse()
        $webCode = [int]$resp.StatusCode
        $resp.Close()
        if ($webCode -eq 200 -or $webCode -eq 302) { $webReady = $true; break }
    } catch {
        $webCode = 0
    }
}
if ($webReady) { Write-Ok "Web 服务已启动 - $mode (HTTP $webCode)" }
else { Write-Err "Web 服务启动异常(HTTP $webCode),请检查 runtime\logs\php-error.log 和 runtime\nginx\logs\error.log" }

$lanIp = ''
try {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' } |
              Select-Object -First 1).IPAddress
} catch { }

Write-Host ""
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  访问地址:  http://127.0.0.1:$HttpPort" -ForegroundColor White
if ($lanIp) {
    Write-Host "  局域网:    http://$lanIp`:$HttpPort   (同一网络内的同事可访问)" -ForegroundColor Gray
}
Write-Host "  运行模式:  $mode" -ForegroundColor Gray
Write-Host "  默认账号:  admin / admin123" -ForegroundColor Gray
Write-Host "  停止服务:  双击「停止系统.bat」" -ForegroundColor Gray
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 退出前的存活自检:进程 + 监听端口
if ($useNginx) {
    $stillAlive = 0
    if ($cgiPids.Count -gt 0) {
        foreach ($id in $cgiPids) { if ($null -ne (Get-Process -Id $id -ErrorAction SilentlyContinue)) { $stillAlive++ } }
    }
    $listening = 0
    for ($i = 0; $i -lt $CgiWorkers; $i++) {
        if (Get-NetTCPConnection -State Listen -LocalPort ($CgiBasePort + $i) -ErrorAction SilentlyContinue) { $listening++ }
    }
    if ($stillAlive -lt $CgiWorkers -or $listening -lt $CgiWorkers) {
        Write-Err "警告:php-cgi 进程池存活 $stillAlive/$CgiWorkers,监听 $listening/$CgiWorkers"
    } else {
        Write-Ok "php-cgi 进程池 $listening/$CgiWorkers 全部就绪"
    }
}

if (-not $NoBrowser -and -not $env:ERP_NO_BROWSER) {
    Start-Process "http://127.0.0.1:$HttpPort/login"
}
