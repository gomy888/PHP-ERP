@echo off
rem =====================================================================
rem  ZhiMeiCheng ERP - Portable (Green) Edition - One-Click Launcher
rem  Double-click this file. First run initializes the database.
rem  NOTE: keep this file ASCII-only; cmd.exe decodes .bat with the
rem        system ANSI code page, so Chinese text here breaks parsing.
rem        All Chinese messages are printed by bin\start.ps1 instead.
rem =====================================================================
chcp 65001 >nul 2>&1
title ZhiMeiCheng ERP Portable
cd /d "%~dp0"

if not exist "runtime\php\php.exe" (
    echo   [ERROR] PHP runtime not found: runtime\php\php.exe
    echo   Please make sure the project folder is complete.
    echo.
    pause
    exit /b 1
)
if not exist "runtime\mysql\bin\mysqld.exe" (
    echo   [ERROR] MySQL runtime not found: runtime\mysql\bin\mysqld.exe
    echo   Please make sure the project folder is complete.
    echo.
    pause
    exit /b 1
)
if not exist "runtime\nginx\nginx.exe" (
    echo   [WARN] nginx not found, fallback to PHP built-in server.
    echo.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\start.ps1"

echo.
echo   Press any key to close this window.
echo   The service keeps running in the background.
echo.
pause >nul
