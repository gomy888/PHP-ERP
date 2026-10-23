<?php
/**
 * 智美成ERP系统 · 加密版入口
 *
 * 业务源码全部以 *.php.enc 形式存放,由 bin/guard/loader.php 在内存中解密加载,
 * 磁盘上不存在明文 PHP。
 */
declare(strict_types=1);

require dirname(__DIR__) . '/bin/guard/loader.php';
erp_guard_boot();
