<?php
/**
 * 智美成ERP系统 · 加密版脚本入口
 *
 * 真正的逻辑在同名的 .php.enc 里,由 bin/guard/loader.php 在内存中解密执行。
 */
declare(strict_types=1);

require dirname(__DIR__) . '/bin/guard/loader.php';
erp_guard_cli(__FILE__);
