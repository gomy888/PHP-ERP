@echo off
rem =====================================================================
rem  ZhiMeiCheng ERP - Portable (Green) Edition - Stop Services
rem  Double-click this file to stop MySQL / nginx / php-cgi.
rem  NOTE: ASCII-only on purpose (see start bat for details).
rem =====================================================================
chcp 65001 >nul 2>&1
title Stop ZhiMeiCheng ERP
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\stop.ps1"

echo.
pause
