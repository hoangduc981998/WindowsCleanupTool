@echo off
echo Dang tai va cai dat Cong Cu Don Dep He Thong...
echo ========================================
echo.

:: Tao thu muc neu chua ton tai
if not exist "%USERPROFILE%\CleanupTool" mkdir "%USERPROFILE%\CleanupTool"

:: Tai script tu GitHub
echo Dang tai script tu GitHub...
powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hoangduc981998/WindowsCleanupTool/main/CleanUpTool.ps1' -OutFile '%USERPROFILE%\CleanupTool\CleanUpTool.ps1' }"

:: Tao shortcut tren Desktop
echo Dang tao shortcut tren Desktop...
powershell -Command "& { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Don Dep He Thong.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-ExecutionPolicy Bypass -File \"%USERPROFILE%\CleanupTool\CleanUpTool.ps1\"'; $Shortcut.WorkingDirectory = '%USERPROFILE%\CleanupTool'; $Shortcut.IconLocation = 'cleanmgr.exe,0'; $Shortcut.Save() }"

:: Tao file chay truc tiep
echo Dang tao file chay truc tiep...
(
echo @echo off
echo powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\CleanupTool\CleanUpTool.ps1"
) > "%USERPROFILE%\Desktop\ChayDonDep.bat"

echo.
echo Cai dat hoan tat!
echo Ban co the chay chuong trinh bang cach:
echo 1. Nhap doi vao shortcut "Don Dep He Thong" tren Desktop
echo 2. Hoac chay file "ChayDonDep.bat"
echo.
echo Nhan phim bat ky de thoat...
pause > nul
