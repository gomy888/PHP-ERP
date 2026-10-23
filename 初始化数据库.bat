@echo off
rem =====================================================================
rem  ZhiMeiCheng ERP - Portable (Green) Edition - (Re)Initialize Database
rem  Double-click this file, then confirm. This rebuilds the database
rem  and ERASES all business data.
rem
rem  You will be asked for the ADMIN password TWICE after the Y/N prompt.
rem  Both entries must match each other AND match the real admin
rem  password, otherwise nothing is deleted.
rem
rem  NOTE: ASCII-only on purpose (see start bat for details).
rem =====================================================================
chcp 65001 >nul 2>&1
title Initialize ZhiMeiCheng ERP Database
cd /d "%~dp0"

echo.
echo   ================================================
echo     This will REBUILD the database and ERASE
echo     all business data.
echo.
echo     You must type the ADMIN PASSWORD twice
echo     to confirm. Both entries must match.
echo   ================================================
echo.
set /p ANS=Continue? (Y/N):
if /i not "%ANS%"=="Y" (
    echo   Cancelled.
    pause
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\setup.ps1" -Fresh
echo.
pause
