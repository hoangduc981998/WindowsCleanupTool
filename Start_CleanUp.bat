@echo off
:: ---------------------------------------------------------
:: LAUNCHER CHO CLEANUP TOOL (POWERSHELL)
:: Tu dong chay voi quyen Admin va Bypass ExecutionPolicy
:: ---------------------------------------------------------

:: 1. Tu dong chuyen ve thu muc chua file nay
cd /d "%~dp0"

:: 2. Kiem tra quyen Admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Dang yeu cau quyen Administrator...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:: 3. Kiem tra xem file PowerShell co ton tai khong
if not exist "CleanUpTool.ps1" (
    color 4F
    echo [LOI] Khong tim thay file 'CleanUpTool.ps1'
    echo Vui long dam bao file .bat va .ps1 nam cung mot thu muc!
    pause
    exit /b
)

:: 4. Chay file PowerShell (Giau cua so CMD den)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "CleanUpTool.ps1"

exit
