<?php
/**
 * 内置服务器路由脚本
 *
 * 存在的静态文件直接返回给服务器,其余请求交给 index.php 处理。
 * 用法: php -S 0.0.0.0:8090 -t public public/router.php
 */
declare(strict_types=1);

$path = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?: '/';
$path = urldecode($path);

// 禁止目录穿越
if (str_contains($path, '..')) {
    http_response_code(400);
    exit('Bad Request');
}

$file = __DIR__ . $path;
if ($path !== '/' && is_file($file)) {
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $mime = [
        'css'  => 'text/css; charset=utf-8',
        'js'   => 'application/javascript; charset=utf-8',
        'json' => 'application/json; charset=utf-8',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif'  => 'image/gif',
        'svg'  => 'image/svg+xml',
        'ico'  => 'image/x-icon',
        'woff' => 'font/woff',
        'woff2' => 'font/woff2',
        'ttf'  => 'font/ttf',
    ];
    if (isset($mime[$ext])) {
        header('Content-Type: ' . $mime[$ext]);
    }
    return false;
}

require __DIR__ . '/index.php';
