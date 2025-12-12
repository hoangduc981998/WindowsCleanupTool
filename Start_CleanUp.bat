@echo off
chcp 65001 >nul
title Windows Cleanup Tool Launcher

REM === Auto-detect script location (works anywhere) ===
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%CleanUpTool.ps1"

REM === Check if script exists ===
if not exist "%SCRIPT_PATH%" (
    echo.
    echo [ERROR] Không tìm thấy file:  CleanUpTool.ps1
    echo.
    echo Vị trí tìm kiếm: %SCRIPT_PATH%
    echo. 
    echo Hãy đảm bảo file . bat và CleanUpTool.ps1 ở cùng thư mục! 
    echo.
    pause
    exit /b 1
)

echo ============================================
echo   Windows Cleanup Tool - Starting...
echo ============================================
echo. 
echo Script location: %SCRIPT_PATH%
echo. 

REM === Run PowerShell as Admin with Bypass policy ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_PATH%\"' -Verb RunAs"

REM === Check if PowerShell started successfully ===
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Không thể khởi động PowerShell! 
    echo.
    echo Lỗi có thể do:
    echo  - Bạn click "Không" khi UAC hỏi quyền Admin
    echo  - PowerShell bị vô hiệu hóa bởi Group Policy
    echo. 
    pause
    exit /b %ERRORLEVEL%
)

echo. 
echo [OK] Đã khởi động tool!  Cửa sổ PowerShell sẽ mở trong giây lát... 
timeout /t 2 >nul
exit /b 0
