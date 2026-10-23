<?php
declare(strict_types=1);

/**
 * 智美成ERP系统 · 加密版装载器(Shell Loader)
 *
 * 职责:
 *   1. 提供内容密钥(CK),按文件派生 AES-256 密钥;
 *   2. 通过自定义流包装器 erp:// 把加密的 .php.enc 还原成 PHP 源码供 include/require 使用,
 *      全程在内存中完成 —— 磁盘上不会出现任何明文源码;
 *   3. 每个文件带 HMAC 完整性校验,被篡改立即报错;
 *   4. 授权门禁:未授权(试用期结束 / 换盘 / 激活码无效)时,只放行渲染激活页所必需的文件。
 *
 * 这个文件本身是明文(入口必须能被 PHP 直接执行),因此它不是安全边界 ——
 * 真正的安全边界是「激活码由厂商 RSA 私钥签发,ERP 侧只有公钥」。
 *
 * @var string ERP_ROOT     站点根目录
 * @var string ERP_PUBLIC_DIR
 * @var string APP_PATH
 */

if (!defined('ERP_ROOT')) {
    define('ERP_ROOT', dirname(__DIR__, 2));
}
if (!defined('ERP_PUBLIC_DIR')) {
    define('ERP_PUBLIC_DIR', ERP_ROOT . '/public');
}
if (!defined('APP_PATH')) {
    define('APP_PATH', ERP_ROOT . '/app');
}

if (!defined('ERP_GUARD_PREFIX')) {
    define('ERP_GUARD_PREFIX', 'erp://');
}

/* ==================================================================== 密钥 */

/**
 * 内容密钥(32 字节)—— 存放于 bin/guard/shell.dat,使用逐字节 XOR 混淆
 */
function erp_guard_content_key(): string
{
    static $ck = null;
    if ($ck !== null) {
        return $ck;
    }
    $file = ERP_ROOT . '/bin/guard/shell.dat';
    $raw = @file_get_contents($file);
    if (!is_string($raw) || trim($raw) === '') {
        throw new RuntimeException('加壳数据损坏:缺少 bin/guard/shell.dat');
    }
    $bin = base64_decode(trim($raw), true);
    if ($bin === false || strlen($bin) !== 32) {
        throw new RuntimeException('加壳数据损坏:shell.dat 格式错误');
    }
    $out = '';
    for ($i = 0; $i < 32; $i++) {
        $out .= chr(ord($bin[$i]) ^ (0x5A ^ ($i % 251)));
    }
    $ck = $out;
    return $ck;
}

/**
 * 单文件密钥
 */
function erp_guard_file_key(string $rel): string
{
    return hash_hmac('sha256', 'zmc-erp-file-v1|' . $rel, erp_guard_content_key(), true);
}

/* ==================================================================== 机器码 */

/**
 * 机器码(硬盘 ID)—— 与 app/Core/License.php 保持同一套算法与同一份缓存
 */
function erp_guard_machine_id(): string
{
    static $mid = null;
    if ($mid !== null) {
        return $mid;
    }
    $cache = ERP_ROOT . '/runtime/hwid.cache';
    $ttl = 21600;
    if (is_file($cache)) {
        $raw = @file_get_contents($cache);
        if (is_string($raw) && $raw !== '') {
            $j = json_decode($raw, true);
            if (is_array($j) && !empty($j['id']) && (time() - (int) ($j['ts'] ?? 0)) < $ttl) {
                $mid = (string) $j['id'];
                return $mid;
            }
        }
    }
    $mid = erp_guard_compute_machine_id();
    @file_put_contents($cache, (string) json_encode([
        'id'  => $mid,
        'raw' => erp_guard_machine_raw(),
        'ts'  => time(),
    ], JSON_UNESCAPED_UNICODE), LOCK_EX);
    return $mid;
}

function erp_guard_machine_raw(): string
{
    $sys = erp_guard_ps(
        '$d = Get-Partition -DriveLetter C -ErrorAction SilentlyContinue | '
        . 'Get-Disk -ErrorAction SilentlyContinue; if ($d) { $d.SerialNumber }'
    );
    return $sys !== '' ? $sys : 'UNKNOWN';
}

function erp_guard_compute_machine_id(): string
{
    $hex = strtoupper(substr(hash('sha256', 'zmc-erp-machine-v1|' . erp_guard_machine_raw()), 0, 25));
    return implode('-', str_split($hex, 5));
}

function erp_guard_ps(string $script): string
{
    if (PHP_OS_FAMILY !== 'Windows') {
        return '';
    }
    $full = '$ProgressPreference=\'SilentlyContinue\'; ' . $script;
    $enc = base64_encode((string) mb_convert_encoding($full, 'UTF-16LE', 'UTF-8'));
    $out = @shell_exec('powershell -NoProfile -NonInteractive -EncodedCommand ' . $enc . ' 2>NUL');
    if (!is_string($out)) {
        return '';
    }
    $out = preg_replace('/#< CLIXML.*/s', '', $out) ?? $out;
    return trim($out);
}

/* ==================================================================== 授权 */

/**
 * 授权状态
 *
 * @return array{ok:bool,mode:string,msg:string,machine_id:string}
 */
function erp_guard_license(): array
{
    static $state = null;
    if ($state !== null) {
        return $state;
    }

    $mid = erp_guard_machine_id();
    $file = ERP_ROOT . '/runtime/license.json';
    $data = [];
    if (is_file($file)) {
        $raw = @file_get_contents($file);
        if (is_string($raw) && $raw !== '') {
            $j = json_decode($raw, true);
            if (is_array($j)) {
                $data = $j;
            }
        }
    }

    // ── 已激活:验签 + 机器码 + 到期
    if (!empty($data['activated']) && !empty($data['payload']) && !empty($data['sig'])) {
        // license.json 里 payload 与 sig 是分字段存的,验签时要还原成
        // ZMC1.<payload>.<sig> 三段格式(与 app/Core/License.php::verify 保持一致)
        $parts = explode('.', 'ZMC1.' . (string) $data['payload'] . '.' . (string) $data['sig']);
        if (count($parts) === 3 && $parts[0] === 'ZMC1') {
            [$tag, $pb64, $sb64] = $parts;
            $json = erp_guard_b64u_decode($pb64);
            $sig = erp_guard_b64u_decode($sb64);
            $payload = $json === false ? null : json_decode($json, true);
            $pub = erp_guard_public_key();
            if (is_array($payload) && $sig !== false && $pub !== ''
                && @openssl_verify((string) $pb64, $sig, $pub, OPENSSL_ALGO_SHA256) === 1) {
                if ((string) ($payload['mid'] ?? '') !== $mid) {
                    $state = ['ok' => false, 'mode' => 'activated', 'machine_id' => $mid,
                        'msg' => '本机硬盘与授权绑定的硬盘不一致'];
                    return $state;
                }
                $exp = (int) ($payload['exp'] ?? 0);
                if ($exp > 0 && $exp < time()) {
                    $state = ['ok' => false, 'mode' => 'activated', 'machine_id' => $mid,
                        'msg' => '授权已于 ' . date('Y-m-d H:i', $exp) . ' 到期'];
                    return $state;
                }
                $state = ['ok' => true, 'mode' => 'activated', 'machine_id' => $mid, 'msg' => ''];
                return $state;
            }
        }
        $state = ['ok' => false, 'mode' => 'activated', 'machine_id' => $mid,
            'msg' => '授权文件校验失败(签名无效或文件被篡改)'];
        return $state;
    }

    // ── 试用
    $install = (int) ($data['installed_at'] ?? 0);
    if ($install <= 0) {
        $install = time();
        $dir = ERP_ROOT . '/runtime';
        if (!is_dir($dir)) {
            @mkdir($dir, 0775, true);
        }
        @file_put_contents($dir . '/license.json', (string) json_encode([
            'version'      => 1,
            'machine_id'   => $mid,
            'installed_at' => $install,
            'trial_days'   => 30,
            'activated'    => false,
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT), LOCK_EX);
    }
    $days = 30;
    $end = $install + $days * 86400;
    $ok = ($end - time()) > 0;
    $state = [
        'ok'         => $ok,
        'mode'       => 'trial',
        'machine_id' => $mid,
        'msg'        => $ok ? '' : '试用期已结束,请输入激活码',
    ];
    return $state;
}

function erp_guard_public_key(): string
{
    $file = ERP_ROOT . '/config/license_pubkey.pem';
    if (!is_file($file)) {
        return '';
    }
    $pem = @file_get_contents($file);
    return is_string($pem) ? trim($pem) : '';
}

function erp_guard_b64u_decode(string $enc): string|false
{
    $enc = strtr(trim($enc), '-_', '+/');
    $pad = strlen($enc) % 4;
    if ($pad > 0) {
        $enc .= str_repeat('=', 4 - $pad);
    }
    $raw = base64_decode($enc, true);
    return $raw === false ? false : $raw;
}

/**
 * 未授权时允许加载的文件(够渲染激活页即可)
 */
function erp_guard_rel_allowed(string $rel): bool
{
    $allow = [
        'config/',
        'app/Core/',
        'app/View/',
        'app/routes.php',
        'app/guard_entry.php',
        'app/Controller/LicenseController.php',
        'public/',
    ];
    foreach ($allow as $prefix) {
        if (strncmp($rel, $prefix, strlen($prefix)) === 0) {
            return true;
        }
    }
    return false;
}

/* ==================================================================== 流包装器 */

/**
 * erp://  →  解密 .php.enc 并以明文源码形式提供给 include/require
 */
final class ErpGuardStream
{
    /** @var resource|null */
    public $context;
    private int $pos = 0;
    private string $data = '';
    private string $rel = '';

    public function stream_open(string $path, string $mode, int $options, ?string &$opened_path): bool
    {
        $rel = substr($path, strlen(ERP_GUARD_PREFIX));
        // 允许直接引用 xxx.php.enc(命令行桩用)
        if (str_ends_with($rel, '.enc')) {
            $rel = substr($rel, 0, -4);
        }
        $this->rel = $rel;
        $abs = ERP_ROOT . '/' . $rel;

        $enc = $abs . '.enc';
        if (is_file($enc)) {
            $lic = erp_guard_license();
            if (!$lic['ok'] && !erp_guard_rel_allowed($rel)) {
                throw new RuntimeException('系统尚未授权(' . $lic['msg'] . '),无法加载业务模块');
            }
            $blob = @file_get_contents($enc);
            if (!is_string($blob)) {
                throw new RuntimeException('加壳数据读取失败:' . $rel);
            }
            $this->data = erp_guard_decrypt($rel, $blob);
            $this->pos = 0;
            return true;
        }

        if (is_file($abs)) {
            $raw = @file_get_contents($abs);
            if (!is_string($raw)) {
                throw new RuntimeException('文件读取失败:' . $rel);
            }
            $this->data = $raw;
            $this->pos = 0;
            return true;
        }

        return false;
    }

    public function stream_read(int $count): string
    {
        $ret = substr($this->data, $this->pos, $count);
        $this->pos += strlen($ret);
        return $ret;
    }

    public function stream_eof(): bool
    {
        return $this->pos >= strlen($this->data);
    }

    public function stream_seek(int $offset, int $whence = SEEK_SET): bool
    {
        if ($whence === SEEK_SET) {
            $this->pos = $offset;
        } elseif ($whence === SEEK_CUR) {
            $this->pos += $offset;
        } else {
            $this->pos = strlen($this->data) + $offset;
        }
        return true;
    }

    public function stream_tell(): int
    {
        return $this->pos;
    }

    public function stream_set_option(int $option, int $arg1, int $arg2): bool
    {
        return true;
    }

    public function stream_stat(): array
    {
        return ['size' => strlen($this->data), 'mode' => 0100777];
    }

    public function url_stat(string $path, int $flags): array|false
    {
        $rel = substr($path, strlen(ERP_GUARD_PREFIX));
        if (str_ends_with($rel, '.enc')) {
            $rel = substr($rel, 0, -4);
        }
        $enc = ERP_ROOT . '/' . $rel . '.enc';
        if (is_file($enc)) {
            return ['size' => (int) @filesize($enc), 'mode' => 0100777];
        }
        $abs = ERP_ROOT . '/' . $rel;
        if (is_file($abs)) {
            return ['size' => (int) @filesize($abs), 'mode' => 0100777];
        }
        return false;
    }
}

/**
 * 解密 + 完整性校验
 */
function erp_guard_decrypt(string $rel, string $blob): string
{
    if (strlen($blob) < 53 || substr($blob, 0, 5) !== 'ERPG1') {
        throw new RuntimeException('加壳数据格式错误:' . $rel);
    }
    $iv = substr($blob, 5, 16);
    $mac = substr($blob, 21, 32);
    $ct = substr($blob, 53);

    $key = erp_guard_file_key($rel);
    $macKey = hash_hmac('sha256', 'zmc-erp-mac-v1|' . $rel, $key, true);
    $expect = hash_hmac('sha256', $iv . $ct, $macKey, true);
    if (!hash_equals($expect, $mac)) {
        throw new RuntimeException('加壳数据校验失败(文件被篡改):' . $rel);
    }
    $plain = openssl_decrypt($ct, 'aes-256-cbc', $key, OPENSSL_RAW_DATA, $iv);
    if (!is_string($plain)) {
        throw new RuntimeException('加壳数据解密失败:' . $rel);
    }
    return $plain;
}

/* ==================================================================== 对外接口 */

/**
 * 绝对路径 → erp:// 包装路径
 */
function erp_guard_path(string $abs): string
{
    $abs = str_replace('\\', '/', $abs);
    $root = str_replace('\\', '/', ERP_ROOT);
    if (strncmp($abs, $root, strlen($root)) === 0) {
        $rel = ltrim(substr($abs, strlen($root)), '/');
    } else {
        $rel = ltrim($abs, '/');
    }
    return ERP_GUARD_PREFIX . $rel;
}

/**
 * 该文件是否存在(加密文件或明文文件都算)
 */
function erp_guard_exists(string $abs): bool
{
    $abs = str_replace('\\', '/', $abs);
    return is_file($abs . '.enc') || is_file($abs);
}

/**
 * 以 include 语义加载(保留调用方作用域)
 */
function erp_guard_include(string $abs): mixed
{
    return require erp_guard_path($abs);
}

function erp_guard_include_once(string $abs): void
{
    require_once erp_guard_path($abs);
}

/**
 * 注册 erp:// 流包装器
 */
function erp_guard_register(): void
{
    if (!in_array('erp', stream_get_wrappers(), true)) {
        stream_wrapper_register('erp', 'ErpGuardStream');
    }
}

/**
 * 命令行脚本入口(database/install.php 等)
 */
function erp_guard_cli(string $stub): void
{
    global $argv, $argc;
    erp_guard_register();
    require erp_guard_path($stub . '.enc');
}

/**
 * Web 入口
 */
function erp_guard_boot(): void
{
    erp_guard_register();
    require erp_guard_path(ERP_ROOT . '/app/guard_entry.php');
}
