# --- 0. TU DONG KIEM TRA QUYEN ADMIN ---
# Support -AutoRun parameter for scheduled cleanup
param(
    [switch]$AutoRun
)

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    # Pass through the -AutoRun parameter if present
    $autoRunArg = if ($AutoRun) { " -AutoRun" } else { "" }
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$autoRunArg"
    $processInfo.Verb = "runas"
    try { [System.Diagnostics.Process]::Start($processInfo) } catch {}
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL VARIABLES ---
$global:InstalledApps = @()
$global:RegIssues = @()
$global:DuplicateFiles = @()

# --- HELPER FUNCTIONS ---

# Function to write log to file with UTF-8 encoding
function Write-CleanupLog {
    param([string]$Message)
    $logFile = "$env:USERPROFILE\Desktop\CleanupTool_$(Get-Date -Format 'yyyyMMdd').log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File $logFile -Append -Encoding UTF8
}

# Function to validate safe paths before deletion
function Test-SafePath {
    param([string]$Path)
    $safePaths = @(
        "$env:TEMP",
        "$env:windir\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:windir\SoftwareDistribution\Download",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    )
    foreach ($safePath in $safePaths) {
        if ($Path -like "$safePath*") {
            return $true
        }
    }
    return $false
}

# Function to estimate disk space that can be freed
function Get-EstimatedSpace {
    $totalSize = 0
    try {
        $tempPaths = @(
            $env:TEMP,
            "$env:windir\Temp",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        )
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                $totalSize += (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            }
        }
    } catch {}
    return [math]::Round($totalSize / 1MB, 2)
}

# --- REGISTRY CLEANER FUNCTIONS ---
function Scan-RegistryIssues {
    $issues = @()
    
    # 1. Scan invalid Uninstall keys
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.InstallLocation -and !(Test-Path $_.InstallLocation -ErrorAction SilentlyContinue)) {
                    $issues += @{
                        Type = "InvalidUninstallEntry"
                        Key = $_.PSPath
                        Description = "Ứng dụng đã gỡ nhưng còn registry: $($_.DisplayName)"
                    }
                }
                
                if ($_.DisplayIcon) {
                    $iconPath = $_.DisplayIcon -replace ',.*', ''
                    if ($iconPath -and !(Test-Path $iconPath -ErrorAction SilentlyContinue)) {
                        $issues += @{
                            Type = "MissingIcon"
                            Key = $_.PSPath
                            Description = "Icon không tồn tại: $($_.DisplayIcon)"
                        }
                    }
                }
            }
        } catch {}
    }
    
    # 2. Scan missing Shared DLLs
    $sharedDLLPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs"
    if (Test-Path $sharedDLLPath) {
        try {
            $props = Get-ItemProperty $sharedDLLPath -ErrorAction SilentlyContinue
            if ($props) {
                $props.PSObject.Properties | Where-Object {$_.Name -notlike 'PS*'} | ForEach-Object {
                    if (!(Test-Path $_.Name -ErrorAction SilentlyContinue)) {
                        $issues += @{
                            Type = "MissingSharedDLL"
                            Key = "$sharedDLLPath"
                            ValueName = $_.Name
                            Description = "DLL không tồn tại: $($_.Name)"
                        }
                    }
                }
            }
        } catch {}
    }
    
    # 3. Scan obsolete MUI Cache
    $muiCachePath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    if (Test-Path $muiCachePath) {
        try {
            $props = Get-ItemProperty $muiCachePath -ErrorAction SilentlyContinue
            if ($props) {
                $props.PSObject.Properties | Where-Object {$_.Name -notlike 'PS*'} | ForEach-Object {
                    $exePath = $_.Name -replace '\.FriendlyAppName$|\.ApplicationCompany$', ''
                    if ($exePath -and $exePath -ne $_.Name -and !(Test-Path $exePath -ErrorAction SilentlyContinue)) {
                        $issues += @{
                            Type = "ObsoleteMuiCache"
                            Key = $muiCachePath
                            ValueName = $_.Name
                            Description = "MUI Cache lỗi thời: $exePath"
                        }
                    }
                }
            }
        } catch {}
    }
    
    Write-CleanupLog "[SCAN] Quét Registry: Tìm thấy $($issues.Count) vấn đề"
    return $issues
}

function Clean-RegistryIssues {
    param([array]$Issues)
    
    # Backup registry first - backup both HKLM and HKCU
    $backupFolder = "$env:USERPROFILE\Desktop"
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupHKLM = "$backupFolder\RegBackup_HKLM_$timestamp.reg"
    $backupHKCU = "$backupFolder\RegBackup_HKCU_$timestamp.reg"
    
    try {
        $proc1 = Start-Process reg -ArgumentList "export HKLM\SOFTWARE `"$backupHKLM`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        $proc2 = Start-Process reg -ArgumentList "export HKCU `"$backupHKCU`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        
        if ($proc1.ExitCode -eq 0 -and $proc2.ExitCode -eq 0) {
            Write-CleanupLog "[OK] Đã sao lưu Registry: $backupHKLM và $backupHKCU"
        } else {
            Write-CleanupLog "[WARN] Sao lưu Registry có thể chưa hoàn chỉnh"
        }
    } catch {
        Write-CleanupLog "[WARN] Không thể sao lưu Registry: $($_.Exception.Message)"
    }
    
    $cleaned = 0
    foreach ($issue in $Issues) {
        try {
            switch ($issue.Type) {
                "InvalidUninstallEntry" {
                    $keyPath = $issue.Key -replace 'Microsoft\.PowerShell\.Core\\Registry::', ''
                    Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                    $cleaned++
                }
                "MissingSharedDLL" {
                    if ($issue.ValueName) {
                        Remove-ItemProperty -Path $issue.Key -Name $issue.ValueName -Force -ErrorAction Stop
                        $cleaned++
                    }
                }
                "ObsoleteMuiCache" {
                    if ($issue.ValueName) {
                        Remove-ItemProperty -Path $issue.Key -Name $issue.ValueName -Force -ErrorAction Stop
                        $cleaned++
                    }
                }
                "MissingIcon" {
                    # Skip icon issues - they don't affect system stability
                }
            }
            Write-CleanupLog "[OK] Đã xóa: $($issue.Description)"
        } catch {
            Write-CleanupLog "[WARN] Không thể xóa: $($issue.Description)"
        }
    }
    
    return $cleaned
}

# --- DUPLICATE FILE FINDER FUNCTIONS ---
function Find-DuplicateFiles {
    param(
        [string]$ScanPath = "$env:USERPROFILE",
        [int]$MinSizeMB = 1
    )
    
    Write-CleanupLog "[SCAN] Đang quét file trùng lặp trong: $ScanPath"
    $duplicates = @()
    
    try {
        $files = Get-ChildItem $ScanPath -Recurse -File -ErrorAction SilentlyContinue | 
                 Where-Object {$_.Length -ge ($MinSizeMB * 1MB)}
        
        $filesBySize = $files | Group-Object -Property Length | Where-Object {$_.Count -gt 1}
        
        foreach ($sizeGroup in $filesBySize) {
            $hashTable = @{}
            
            foreach ($file in $sizeGroup.Group) {
                try {
                    $hash = (Get-FileHash $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
                    
                    if ($hash) {
                        if ($hashTable.ContainsKey($hash)) {
                            $hashTable[$hash] += @($file.FullName)
                        } else {
                            $hashTable[$hash] = @($file.FullName)
                        }
                    }
                } catch {}
            }
            
            foreach ($hash in $hashTable.Keys) {
                if ($hashTable[$hash].Count -gt 1) {
                    $firstFile = Get-Item $hashTable[$hash][0] -ErrorAction SilentlyContinue
                    $duplicates += @{
                        Hash = $hash
                        Files = $hashTable[$hash]
                        Size = if ($firstFile) { $firstFile.Length } else { 0 }
                        FileName = if ($firstFile) { $firstFile.Name } else { "" }
                    }
                }
            }
        }
    } catch {
        Write-CleanupLog "[ERROR] Lỗi quét: $($_.Exception.Message)"
    }
    
    Write-CleanupLog "[SCAN] Tìm thấy $($duplicates.Count) nhóm file trùng lặp"
    return $duplicates
}

function Remove-DuplicateFiles {
    param([array]$FilesToDelete)
    
    $totalFreed = 0
    $deletedCount = 0
    foreach ($file in $FilesToDelete) {
        try {
            if (Test-Path $file) {
                $size = (Get-Item $file -ErrorAction SilentlyContinue).Length
                Remove-Item $file -Force -ErrorAction Stop
                $totalFreed += $size
                $deletedCount++
                Write-CleanupLog "[OK] Đã xóa: $file"
            }
        } catch {
            Write-CleanupLog "[ERROR] Lỗi xóa: $file - $($_.Exception.Message)"
        }
    }
    
    return @{
        DeletedCount = $deletedCount
        FreedMB = [math]::Round($totalFreed / 1MB, 2)
    }
}

# --- HEALTH CHECK FUNCTIONS ---
function Get-SystemHealth {
    $health = @{}
    
    # CPU Usage
    try {
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        $health.CPU = [math]::Round($cpu, 1)
    } catch {
        $health.CPU = 0
    }
    
    # RAM Usage
    try {
        $ram = (Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        $health.RAM = [math]::Round($ram, 1)
    } catch {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $health.RAM = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
        } else {
            $health.RAM = 0
        }
    }
    
    # Disk Space
    try {
        $disk = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($disk) {
            $health.DiskFreeGB = [math]::Round($disk.Free / 1GB, 2)
            $total = $disk.Free + $disk.Used
            $health.DiskUsedPercent = if ($total -gt 0) { [math]::Round(($disk.Used / $total) * 100, 1) } else { 0 }
        } else {
            $health.DiskFreeGB = 0
            $health.DiskUsedPercent = 0
        }
    } catch {
        $health.DiskFreeGB = 0
        $health.DiskUsedPercent = 0
    }
    
    # Temp Files
    $tempSize = 0
    try {
        if (Test-Path $env:TEMP) {
            $tempSum = (Get-ChildItem $env:TEMP -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($tempSum) { $tempSize += $tempSum }
        }
        if (Test-Path "$env:windir\Temp") {
            $winTempSum = (Get-ChildItem "$env:windir\Temp" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($winTempSum) { $tempSize += $winTempSum }
        }
    } catch {}
    $health.TempSizeMB = [math]::Round($tempSize / 1MB, 2)
    
    # Startup Apps
    $startupCount = 0
    try {
        $regProps = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
        if ($regProps) {
            $startupCount = ($regProps.PSObject.Properties | Where-Object {$_.Name -notlike 'PS*'}).Count
        }
    } catch {}
    $health.StartupApps = [math]::Max($startupCount, 0)
    
    # Health Score
    $score = 100
    if ($health.CPU -gt 80) { $score -= 10 }
    if ($health.RAM -gt 80) { $score -= 10 }
    if ($health.DiskUsedPercent -gt 90) { $score -= 20 }
    if ($health.TempSizeMB -gt 1000) { $score -= 15 }
    if ($health.StartupApps -gt 15) { $score -= 15 }
    
    $health.Score = [math]::Max($score, 0)
    
    # Recommendations
    $health.Recommendations = @()
    if ($health.TempSizeMB -gt 500) { 
        $health.Recommendations += "[!] Dọn Temp files ($($health.TempSizeMB) MB)" 
    }
    if ($health.StartupApps -gt 10) { 
        $health.Recommendations += "[!] Giảm Startup apps (hiện tại: $($health.StartupApps))" 
    }
    if ($health.DiskUsedPercent -gt 85) { 
        $health.Recommendations += "[!] Ổ đĩa gần đầy ($($health.DiskUsedPercent)%)" 
    }
    if ($health.CPU -gt 70) {
        $health.Recommendations += "[!] CPU đang tải cao ($($health.CPU)%)"
    }
    if ($health.RAM -gt 80) {
        $health.Recommendations += "[!] RAM đang sử dụng nhiều ($($health.RAM)%)"
    }
    
    return $health
}

# --- ADVANCED UNINSTALLER FUNCTIONS ---
function Get-InstalledApps {
    $apps = @()
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object {$_.DisplayName -and $_.UninstallString} | 
            ForEach-Object {
                $apps += [PSCustomObject]@{
                    Name = $_.DisplayName
                    Publisher = if ($_.Publisher) { $_.Publisher } else { "N/A" }
                    Version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "N/A" }
                    InstallDate = if ($_.InstallDate) { $_.InstallDate } else { "N/A" }
                    UninstallString = $_.UninstallString
                    InstallLocation = $_.InstallLocation
                    EstimatedSize = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 2) } else { 0 }
                    RegistryPath = $_.PSPath
                }
            }
        } catch {}
    }
    
    return $apps | Sort-Object Name -Unique
}

function Uninstall-AppCompletely {
    param(
        [string]$UninstallString, 
        [string]$AppName, 
        [string]$InstallLocation
    )
    
    try {
        Write-CleanupLog "[UNINSTALL] Đang gỡ cài đặt: $AppName"
        
        # Run uninstaller
        if ($UninstallString -like "*msiexec*") {
            # Improved MSI product code regex: exactly 8-4-4-4-12 hex characters
            if ($UninstallString -match '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}') {
                $productCode = $matches[0]
                $proc = Start-Process msiexec -ArgumentList "/x $productCode /qn /norestart" -Wait -PassThru -NoNewWindow -ErrorAction Stop
            } else {
                # Fallback: run the original uninstall command with silent flag
                $proc = Start-Process cmd -ArgumentList "/c `"$UninstallString`" /qn" -Wait -PassThru -NoNewWindow -ErrorAction Stop
            }
        } else {
            $cleanCmd = $UninstallString -replace '^"([^"]+)".*', '$1'
            $existingArgs = $UninstallString -replace '^"[^"]+"(.*)$', '$1'
            
            # Only add silent args if no args exist, don't override existing args
            if (!$existingArgs -or $existingArgs -eq $UninstallString) { 
                $existingArgs = "/S"  # Use only /S which is most universal
            }
            
            if (Test-Path $cleanCmd -ErrorAction SilentlyContinue) {
                $proc = Start-Process $cleanCmd -ArgumentList $existingArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            } else {
                # Fallback: run the original uninstall command as-is
                $proc = Start-Process cmd -ArgumentList "/c `"$UninstallString`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
            }
        }
        
        Write-CleanupLog "[OK] Đã gỡ cài đặt: $AppName"
        
        # Remove leftover folders
        if ($InstallLocation -and (Test-Path $InstallLocation -ErrorAction SilentlyContinue)) {
            Remove-Item $InstallLocation -Recurse -Force -ErrorAction SilentlyContinue
            Write-CleanupLog "[OK] Đã xóa thư mục: $InstallLocation"
        }
        
        # Remove AppData - use less aggressive sanitization
        $cleanAppName = $AppName -replace '[<>:"/\\|?*]', ''  # Only remove invalid path chars
        $appDataPaths = @(
            "$env:LOCALAPPDATA\$cleanAppName",
            "$env:APPDATA\$cleanAppName",
            "$env:ProgramData\$cleanAppName"
        )
        
        foreach ($path in $appDataPaths) {
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-CleanupLog "[OK] Đã xóa AppData: $path"
            }
        }
        
        return $true
    } catch {
        Write-CleanupLog "[ERROR] Lỗi gỡ cài đặt: $AppName - $($_.Exception.Message)"
        return $false
    }
}

# Function to create System Restore Point before cleanup
function New-CleanupRestorePoint {
    param([object]$logBox)
    try {
        # Enable System Restore if disabled
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Trước khi Cleanup - $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã Tạo Restore Point`n")
        $logBox.ScrollToCaret()
        Write-CleanupLog "Đã tạo Restore Point thành công"
        return $true
    } catch {
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Khong the tao Restore Point: $($_.Exception.Message)`n")
        $logBox.ScrollToCaret()
        Write-CleanupLog "Lỗi tạo Restore Point: $($_.Exception.Message)"
        return $false
    }
}

# --- 1. CAU HINH UI ---
$Color_Bg       = [System.Drawing.Color]::WhiteSmoke
$Color_Panel    = [System.Drawing.Color]::White
$Color_Accent   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$Color_Green    = [System.Drawing.Color]::SeaGreen
$Color_Text     = [System.Drawing.Color]::FromArgb(20, 20, 20)
$Color_Desc     = [System.Drawing.Color]::FromArgb(80, 80, 80)

$Font_Header    = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$Font_Title     = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$Font_Normal    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$Font_Desc      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# --- 2. KHOI TAO FORM ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Maintenance Tool v12.0 (CCleaner Pro Features)"
$form.Size = New-Object System.Drawing.Size(1000, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Color_Bg
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:windir\system32\cleanmgr.exe") } catch {}

$tooltip = New-Object System.Windows.Forms.ToolTip; $tooltip.AutoPopDelay = 30000; $tooltip.InitialDelay = 500; $tooltip.ReshowDelay = 200; $tooltip.IsBalloon = $true; $tooltip.ToolTipIcon = "Info"; $tooltip.ToolTipTitle = "Chi tiết"

# --- 3. HEADER ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(1000, 90)
$headerPanel.BackColor = $Color_Accent; $headerPanel.Dock = "Top"

$lblHead = New-Object System.Windows.Forms.Label
$lblHead.Text = "SYSTEM CLEANER & OPTIMIZER"
$lblHead.Font = $Font_Header; $lblHead.ForeColor = [System.Drawing.Color]::White
$lblHead.Location = New-Object System.Drawing.Point(20, 10); $lblHead.AutoSize = $true
$headerPanel.Controls.Add($lblHead)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Phiên bản v12.0 - CCleaner Pro Features: Registry, Duplicate Finder, Health Dashboard, Uninstaller"
$lblSub.Font = $Font_Normal; $lblSub.ForeColor = [System.Drawing.Color]::WhiteSmoke
$lblSub.Location = New-Object System.Drawing.Point(25, 50); $lblSub.AutoSize = $true
$headerPanel.Controls.Add($lblSub)
$form.Controls.Add($headerPanel)

# --- 3.5 HEALTH DASHBOARD PANEL ---
$healthPanel = New-Object System.Windows.Forms.Panel
$healthPanel.Location = New-Object System.Drawing.Point(10, 95)
$healthPanel.Size = New-Object System.Drawing.Size(965, 85)
$healthPanel.BackColor = [System.Drawing.Color]::White
$healthPanel.BorderStyle = "FixedSingle"

# Health Score Label
$lblHealthScore = New-Object System.Windows.Forms.Label
$lblHealthScore.Text = "Sức khỏe: --"
$lblHealthScore.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblHealthScore.Location = New-Object System.Drawing.Point(10, 8)
$lblHealthScore.Size = New-Object System.Drawing.Size(180, 35)
$lblHealthScore.ForeColor = $Color_Green
$healthPanel.Controls.Add($lblHealthScore)

# CPU Progress Bar
$lblCpu = New-Object System.Windows.Forms.Label
$lblCpu.Text = "CPU: --%"
$lblCpu.Font = $Font_Desc
$lblCpu.Location = New-Object System.Drawing.Point(200, 10)
$lblCpu.Size = New-Object System.Drawing.Size(80, 20)
$healthPanel.Controls.Add($lblCpu)

$progCpu = New-Object System.Windows.Forms.ProgressBar
$progCpu.Location = New-Object System.Drawing.Point(280, 10)
$progCpu.Size = New-Object System.Drawing.Size(100, 18)
$progCpu.Maximum = 100
$healthPanel.Controls.Add($progCpu)

# RAM Progress Bar
$lblRam = New-Object System.Windows.Forms.Label
$lblRam.Text = "RAM: --%"
$lblRam.Font = $Font_Desc
$lblRam.Location = New-Object System.Drawing.Point(200, 35)
$lblRam.Size = New-Object System.Drawing.Size(80, 20)
$healthPanel.Controls.Add($lblRam)

$progRam = New-Object System.Windows.Forms.ProgressBar
$progRam.Location = New-Object System.Drawing.Point(280, 35)
$progRam.Size = New-Object System.Drawing.Size(100, 18)
$progRam.Maximum = 100
$healthPanel.Controls.Add($progRam)

# Disk Progress Bar
$lblDisk = New-Object System.Windows.Forms.Label
$lblDisk.Text = "Ổ đĩa: --%"
$lblDisk.Font = $Font_Desc
$lblDisk.Location = New-Object System.Drawing.Point(200, 60)
$lblDisk.Size = New-Object System.Drawing.Size(80, 20)
$healthPanel.Controls.Add($lblDisk)

$progDisk = New-Object System.Windows.Forms.ProgressBar
$progDisk.Location = New-Object System.Drawing.Point(280, 60)
$progDisk.Size = New-Object System.Drawing.Size(100, 18)
$progDisk.Maximum = 100
$healthPanel.Controls.Add($progDisk)

# Recommendations ListBox
$lstRecommendations = New-Object System.Windows.Forms.ListBox
$lstRecommendations.Location = New-Object System.Drawing.Point(400, 8)
$lstRecommendations.Size = New-Object System.Drawing.Size(420, 68)
$lstRecommendations.Font = $Font_Desc
$lstRecommendations.BorderStyle = "FixedSingle"
$healthPanel.Controls.Add($lstRecommendations)

# Refresh Health Button
$btnRefreshHealth = New-Object System.Windows.Forms.Button
$btnRefreshHealth.Text = [char]0x27F3
$btnRefreshHealth.Location = New-Object System.Drawing.Point(830, 15)
$btnRefreshHealth.Size = New-Object System.Drawing.Size(50, 50)
$btnRefreshHealth.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$btnRefreshHealth.FlatStyle = "Flat"
$btnRefreshHealth.BackColor = $Color_Accent
$btnRefreshHealth.ForeColor = [System.Drawing.Color]::White
$tooltip.SetToolTip($btnRefreshHealth, "Làm mới thông tin sức khỏe hệ thống")
$healthPanel.Controls.Add($btnRefreshHealth)

# Temp Files Label
$lblTempInfo = New-Object System.Windows.Forms.Label
$lblTempInfo.Text = "Temp: -- MB | Startup: --"
$lblTempInfo.Font = $Font_Desc
$lblTempInfo.Location = New-Object System.Drawing.Point(10, 48)
$lblTempInfo.Size = New-Object System.Drawing.Size(180, 30)
$lblTempInfo.ForeColor = $Color_Desc
$healthPanel.Controls.Add($lblTempInfo)

# Function to update health dashboard
$UpdateHealthDashboard = {
    $health = Get-SystemHealth
    
    # Update Score
    $lblHealthScore.Text = "Sức khỏe: $($health.Score)/100"
    if ($health.Score -ge 80) {
        $lblHealthScore.ForeColor = $Color_Green
    } elseif ($health.Score -ge 60) {
        $lblHealthScore.ForeColor = [System.Drawing.Color]::Orange
    } else {
        $lblHealthScore.ForeColor = [System.Drawing.Color]::Red
    }
    
    # Update Progress Bars
    $lblCpu.Text = "CPU: $($health.CPU)%"
    $progCpu.Value = [math]::Min([int]$health.CPU, 100)
    
    $lblRam.Text = "RAM: $($health.RAM)%"
    $progRam.Value = [math]::Min([int]$health.RAM, 100)
    
    $lblDisk.Text = "Ổ đĩa: $($health.DiskUsedPercent)%"
    $progDisk.Value = [math]::Min([int]$health.DiskUsedPercent, 100)
    
    $lblTempInfo.Text = "Temp: $($health.TempSizeMB) MB | Startup: $($health.StartupApps)"
    
    # Update Recommendations
    $lstRecommendations.Items.Clear()
    if ($health.Recommendations.Count -eq 0) {
        $lstRecommendations.Items.Add("[OK] Hệ thống hoạt động tốt!")
    } else {
        foreach ($rec in $health.Recommendations) {
            $lstRecommendations.Items.Add($rec)
        }
    }
}

$btnRefreshHealth.Add_Click($UpdateHealthDashboard)

$form.Controls.Add($healthPanel)

# --- 4. TAB CONTROL ---
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 185)
$tabControl.Size = New-Object System.Drawing.Size(965, 360)
$tabControl.Font = $Font_Normal

$tabBasic = New-Object System.Windows.Forms.TabPage "Dọn Dẹp Cơ Bản"
$tabAdv = New-Object System.Windows.Forms.TabPage "Nâng Cao"
$tabOpt = New-Object System.Windows.Forms.TabPage "Tối Ưu"
$tabSec = New-Object System.Windows.Forms.TabPage "Bảo Mật"
$tabPriv = New-Object System.Windows.Forms.TabPage "Riêng Tư"
$tabWinget = New-Object System.Windows.Forms.TabPage "Cập Nhật App"
$tabUtils = New-Object System.Windows.Forms.TabPage "Tiện Ích"
$tabRegistry = New-Object System.Windows.Forms.TabPage "Registry"
$tabDuplicates = New-Object System.Windows.Forms.TabPage "File Trùng"
$tabUninstaller = New-Object System.Windows.Forms.TabPage "Gỡ Cài Đặt"

$tabs = @($tabBasic, $tabAdv, $tabOpt, $tabSec, $tabPriv, $tabWinget, $tabUtils, $tabRegistry, $tabDuplicates, $tabUninstaller)
foreach ($t in $tabs) { $t.BackColor = $Color_Panel; $t.UseVisualStyleBackColor = $true; $t.AutoScroll = $true; $tabControl.Controls.Add($t) }
$form.Controls.Add($tabControl)

# --- 5. CORE LOGIC (TACH RIENG DE NUT NAO CUNG GOI DUOC) ---
# Ham chay lenh an toan (Chong treo giao dien)
function Run-Safe($cmd, $cmdArgs, $timeoutSeconds = 300) {
    $p = Start-Process $cmd $cmdArgs -PassThru -NoNewWindow -ErrorAction SilentlyContinue
    if ($p) {
        $timeout = [datetime]::Now.AddSeconds($timeoutSeconds)
        
        while (-not $p.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
            
            # [OK] Timeout protection
            if ([datetime]::Now -gt $timeout) {
                $p.Kill()
                throw "Timeout sau $timeoutSeconds giây"
            }
        }
        
        # [OK] Kiểm tra exit code
        if ($p.ExitCode -ne 0) {
            throw "Lệnh thất bại với mã lỗi: $($p.ExitCode)"
        }
    }
}

# Logic xu ly chinh (Dung chung cho ca Nut to va Nut nho)
$CoreLogic = {
    param($taskList)
    
    $btnRun.Enabled = $false
    $prog.Value = 0
    
    if($taskList.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Chưa chọn mục nào!", "Thông báo"); $btnRun.Enabled=$true; return }

    # Show estimated disk space before cleanup
    $estimatedSpace = Get-EstimatedSpace
    $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Ước tính dung lượng có thể giải phóng: ~$estimatedSpace MB`n")
    $logBox.ScrollToCaret()
    Write-CleanupLog "Bắt đầu cleanup - Ước tính giải phóng: ~$estimatedSpace MB"

    # Kiểm tra restore point gần nhất
    $createRestorePoint = $true

    try {
        $wmiQuery = "SELECT * FROM SystemRestore"
        $restorePoints = Get-CimInstance -Query $wmiQuery -Namespace root\default -ErrorAction Stop | 
                         Sort-Object SequenceNumber -Descending
        
        if ($restorePoints -and $restorePoints.Count -gt 0) {
            $lastRP = $restorePoints[0]
            
            if ($lastRP.CreationTime) {
                $timeSinceLastRestore = (Get-Date) - $lastRP.CreationTime
                $minutesAgo = [math]::Round($timeSinceLastRestore.TotalMinutes, 1)
                
                if ($timeSinceLastRestore.TotalMinutes -lt 30) {
                    $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Đã có restore point trong 30 phút gần đây ($minutesAgo phút trước). Bỏ qua tạo mới.`n")
                    $logBox.ScrollToCaret()
                    Write-CleanupLog "Bỏ qua tạo Restore Point - đã có restore point $minutesAgo phút trước"
                    $createRestorePoint = $false
                } else {
                    $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Restore point gần nhất: $minutesAgo phút trước. Tạo mới...`n")
                    $logBox.ScrollToCaret()
                }
            } else {
                throw "CreationTime is null"
            }
        } else {
            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Chưa có restore point nào. Tạo mới... `n")
            $logBox.ScrollToCaret()
        }
    } catch {
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Không thể kiểm tra restore point. Tạo mới để an toàn...`n")
        $logBox.ScrollToCaret()
        Write-CleanupLog "Lỗi kiểm tra restore point: $($_.Exception.Message)"
        $createRestorePoint = $true
    }

    if ($createRestorePoint) {
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [REFRESH] Đang tạo điểm khôi phục hệ thống...`n")
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
        New-CleanupRestorePoint -logBox $logBox
    }

    $taskIndex = 0
    $totalTasks = $taskList.Count
    foreach($taskKey in $taskList.Keys){
        $taskIndex++
        $prog.Value = [int](($taskIndex / $totalTasks) * 100)
        $form.Text = "Cleanup Tool - Đang xử lý: $taskIndex/$totalTasks"
        
        # Cap nhat giao dien ngay lap tuc
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đang xử lý: $($taskList[$taskKey])...`n")
        $logBox.ScrollToCaret()
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
        Write-CleanupLog "Đang xử lý: $($taskList[$taskKey])"
        
        try{
            switch($taskKey){
                "TempFiles"{
                    try {
                        if (Test-Path "$env:TEMP") {
                            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction Stop
                        }
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã xóa User Temp files`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Một số Temp files đang được sử dụng`n")
                    }
                    try {
                        if (Test-Path "$env:windir\Temp") {
                            Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction Stop
                        }
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã xóa Windows Temp files`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Một số Windows Temp files đang được sử dụng`n")
                    }
                }
                "RecycleBin"{
                    try {
                        Clear-RecycleBin -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã dọn Thùng rác`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Thùng rác đã trống hoặc lỗi: $($_.Exception.Message)`n")
                    }
                }
                "BrowserCache"{
                    try {
                        Stop-Process -Name chrome,msedge,firefox -Force -ErrorAction SilentlyContinue
                        Start-Sleep 1
                        $chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                        if (Test-Path $chromeCache) {
                            Remove-Item "$chromeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                        if (Test-Path $edgeCache) {
                            Remove-Item "$edgeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã xóa cache trình duyệt`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi cache: $($_.Exception.Message)`n")
                    }
                }
                "WinUpdateCache"{
                    try {
                        Stop-Service wuauserv -ErrorAction SilentlyContinue
                        if (Test-Path "$env:windir\SoftwareDistribution\Download") {
                            Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction Stop
                        }
                        Start-Service wuauserv -ErrorAction SilentlyContinue
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã xóa Windows Update Cache`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Update Cache: $($_.Exception.Message)`n")
                        Start-Service wuauserv -ErrorAction SilentlyContinue
                    }
                }
                "ThumbnailCache"{
                    try {
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep 1
                        if (Test-Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer") {
                            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                        }
                        Start-Process explorer
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã xóa Thumbnail cache`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Thumbnail: $($_.Exception.Message)`n")
                        Start-Process explorer -ErrorAction SilentlyContinue
                    }
                }
                
                # --- CAC TAC VU NANG (Dung Run-Safe de chong treo) ---
				"WinSxS" {
					try {
						$proc = Start-Process "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" `
							-Wait -PassThru -NoNewWindow -ErrorAction Stop
        
						switch ($proc.ExitCode) {
							0 { 
								Write-CleanupLog "[OK] Đã dọn WinSxS" 
							}
							-2146498554 { # CBS_E_PENDING
								Write-CleanupLog "[INFO] Component Store đang được sử dụng bởi Windows Update. Thử lại sau."
							}
							default { 
								Write-CleanupLog "[WARN] Lỗi WinSxS: Exit code: $($proc.ExitCode)" 
							}
						}
					} catch {
						Write-CleanupLog "[ERROR] Lỗi WinSxS: $($_.Exception.Message)"
					}
				}
                "StoreCache"{ 
                    try {
                        $wsreset = "$env:windir\System32\WSReset.exe"
                        if (Test-Path $wsreset) {
                            Start-Process $wsreset -Wait -NoNewWindow -ErrorAction Stop
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã reset Store Cache`n")
                            Write-CleanupLog "Đã reset Microsoft Store"
                        } else {
                            throw "WSReset.exe không tìm thấy"
                        }
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Store Cache: $($_.Exception.Message)`n")
                        Write-CleanupLog "Lỗi Store Cache: $($_.Exception.Message)"
                    }
                }
                "Hibernation"{ 
                    try {
                        Start-Process "powercfg.exe" -ArgumentList "/hibernate off" -Wait -NoNewWindow -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Hibernation`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Hibernation: $($_.Exception.Message)`n")
                    }
                }
                "CompressNTFS"{ 
                    try {
                        $proc = Start-Process "compact.exe" -ArgumentList "/CompactOS:always" -Wait -PassThru -NoNewWindow -ErrorAction Stop
                        if ($proc.ExitCode -eq 0) {
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã nén NTFS`n")
                            Write-CleanupLog "Đã bật CompactOS"
                        } else {
                            throw "Exit code: $($proc.ExitCode). Có thể hệ thống đã được nén rồi."
                        }
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi nén NTFS: $($_.Exception.Message)`n")
                        Write-CleanupLog "Lỗi CompactOS: $($_.Exception.Message)"
                    }
                }
                
                "StartupOptimize"{
                    try {
                        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                        Set-ItemProperty $regPath -Name "StartupDelayInMSec" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tối ưu Startup`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Startup: $($_.Exception.Message)`n")
                    }
                }
                "ServiceOptimize"{
                    try {
                        Stop-Service "DiagTrack" -ErrorAction SilentlyContinue
                        Set-Service "DiagTrack" -StartupType Disabled -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tối ưu Services`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Services: $($_.Exception.Message)`n")
                    }
                }
                "BasicMalware"{ 
                    try {
                        if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                            Start-MpScan -ScanType QuickScan -AsJob | Out-Null
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã bắt đầu quét virus`n")
                        } else {
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Windows Defender không khả dụng`n")
                        }
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi quét virus: $($_.Exception.Message)`n")
                    }
                }
                "EnsureFirewallEnabled"{
                    try {
                        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã bật Firewall`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Firewall: $($_.Exception.Message)`n")
                    }
                }
                "EnablePUAProtection"{
                    try {
                        $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
                        if ($defenderService -and $defenderService.Status -eq 'Running') {
                            Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã bật PUA Protection`n")
                            Write-CleanupLog "Đã bật PUA Protection"
                        } else {
                            throw "Windows Defender chưa chạy hoặc không khả dụng"
                        }
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi PUA: $($_.Exception.Message)`n")
                        Write-CleanupLog "Lỗi PUA: $($_.Exception.Message)"
                    }
                }
                "DisableMicrophone"{
                    try {
                        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
                        if (-not (Test-Path $regPath)) { 
                            New-Item -Path $regPath -Force | Out-Null 
                        }
                        Set-ItemProperty -Path $regPath -Name "Value" -Value "Deny" -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Microphone`n")
                        Write-CleanupLog "Đã tắt Microphone"
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Microphone: $($_.Exception.Message)`n")
                        Write-CleanupLog "Lỗi Microphone: $($_.Exception.Message)"
                    }
                }
                "DisableAdvertisingID"{
                    try {
                        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                        Set-ItemProperty $regPath -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Advertising ID`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Advertising: $($_.Exception.Message)`n")
                    }
                }
                "DisableTelemetryServices"{
                    try {
                        Stop-Service "DiagTrack","dmwappushservice" -ErrorAction SilentlyContinue
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Telemetry`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Telemetry: $($_.Exception.Message)`n")
                    }
                }
                
                "HighPerfPlan"{ 
                    try {
                        $guid = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61)
                        if ($guid -match '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b') {
                            powercfg /setactive $matches[0]
                            $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã bật High Performance`n")
                        }
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Power Plan: $($_.Exception.Message)`n")
                    }
                }
                "DisableGameDVR"{ 
                    try {
                        Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Game DVR`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Game DVR: $($_.Exception.Message)`n")
                    }
                }
                "DisableStickyKeys"{ 
                    try {
                        Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value 506 -Type String -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Sticky Keys`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Sticky Keys: $($_.Exception.Message)`n")
                    }
                }
                "ShowExtensions"{ 
                    try {
                        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force -ErrorAction Stop
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Process explorer
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã hiện Extensions`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Extensions: $($_.Exception.Message)`n")
                    }
                }
                "DisableRemoteAssist"{ 
                    try {
                        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Remote Assist`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Remote Assist: $($_.Exception.Message)`n")
                    }
                }
                "DisableSMB1"{ 
                    try {
                        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt SMB1`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi SMB1: $($_.Exception.Message)`n")
                    }
                }
                "DisableCortana"{ 
                    try {
                        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
                        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                        Set-ItemProperty $regPath -Name "AllowCortana" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Cortana`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Cortana: $($_.Exception.Message)`n")
                    }
                }
                "DisableStartSugg"{ 
                    try {
                        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Start Suggestions`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Start Suggestions: $($_.Exception.Message)`n")
                    }
                }
                "DisableFeedback"{ 
                    try {
                        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Siuf\Rules"
                        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                        Set-ItemProperty $regPath -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Feedback`n")
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Feedback: $($_.Exception.Message)`n")
                    }
                }
                "DisableCloudClipboard"{
                    try {
                        $regPath = "HKCU:\Software\Microsoft\Clipboard"
                        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                        Set-ItemProperty $regPath -Name "EnableClipboardHistory" -Value 0 -Type DWord -Force -ErrorAction Stop
                        Set-ItemProperty $regPath -Name "CloudClipboardEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Đã tắt Cloud Clipboard`n")
                        Write-CleanupLog "Đã tắt Cloud Clipboard"
                    } catch {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [WARN] Lỗi Cloud Clipboard: $($_.Exception.Message)`n")
                        Write-CleanupLog "Lỗi Cloud Clipboard: $($_.Exception.Message)"
                    }
                }
            }
            $logBox.AppendText("=> [OK]`n")
            $logBox.ScrollToCaret()
            Write-CleanupLog "Hoàn thành: $($taskList[$taskKey])"
        }catch{
            $logBox.AppendText("=> [SKIP/ERROR] $($_.Exception.Message)`n")
            $logBox.ScrollToCaret()
            Write-CleanupLog "Lỗi: $($taskList[$taskKey]) - $($_.Exception.Message)"
        }
    }
    $form.Text = "System Maintenance Tool v12.0 (CCleaner Pro Features)"
    $logBox.AppendText("=== [OK] HOÀN TẤT ===`n")
    $logBox.ScrollToCaret()
    Write-CleanupLog "Hoàn tất cleanup"
    [System.Windows.Forms.MessageBox]::Show("Đã hoàn thành tác vụ!", "Thông báo")
    $btnRun.Enabled=$true
}

# --- 6. HAM TAO UI (DA GAN LOGIC CHO NUT CHAY NHANH) ---
function Add-TaskItem($tab, $items, $hasQuickAction=$false) {
    $y = 20
    $dict = @{}
    
    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = "Chọn Tất Cả"; $btnAll.Location = New-Object System.Drawing.Point(30, $y); $btnAll.Size = New-Object System.Drawing.Size(120, 35)
    $btnAll.Add_Click({ $this.Parent.Controls | Where {$_.GetType() -eq [System.Windows.Forms.CheckBox]} | ForEach { $_.Checked = $true } })
    $tab.Controls.Add($btnAll)
    
    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = "Bỏ Chọn"; $btnNone.Location = New-Object System.Drawing.Point(160, $y); $btnNone.Size = New-Object System.Drawing.Size(120, 35)
    $btnNone.Add_Click({ $this.Parent.Controls | Where {$_.GetType() -eq [System.Windows.Forms.CheckBox]} | ForEach { $_.Checked = $false } })
    $tab.Controls.Add($btnNone)

    if ($hasQuickAction) {
        $btnQuick = New-Object System.Windows.Forms.Button
        $btnQuick.Text = "CHẠY NHANH TAB NÀY"; $btnQuick.Location = New-Object System.Drawing.Point(700, $y); $btnQuick.Size = New-Object System.Drawing.Size(200, 35)
        $btnQuick.BackColor = $Color_Green; $btnQuick.ForeColor = [System.Drawing.Color]::White; $btnQuick.FlatStyle = "Flat"
        
        # FIX: Gan su kien Click cho nut chay nhanh
		$btnQuick.Add_Click({
			# [OK] Ngăn click nhiều lần
			if (-not $this.Enabled) { return }
			$this.Enabled = $false
    
			$currentTasks = @{}
			$this.Parent.Controls | Where-Object {
				$_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked
			} | ForEach-Object { 
				$currentTasks[$_.Tag] = $_.Text 
			}
    
			& $CoreLogic $currentTasks
    
			# [OK] Bật lại nút sau khi chạy xong
			$this.Enabled = $true
		}. GetNewClosure())  # [OK] QUAN TRỌNG: Tránh scope leak
        
        $tab.Controls.Add($btnQuick)
    }
    
    $y += 50

    foreach ($i in $items) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $i.T; $chk.Tag = $i.Tag
        $chk.Location = New-Object System.Drawing.Point(30, $y); $chk.Size = New-Object System.Drawing.Size(320, 25)
        $chk.Font = $Font_Title; $chk.ForeColor = $Color_Text; $chk.Cursor = "Hand"
        $tooltip.SetToolTip($chk, $i.D)
        
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $i.D; $lbl.Location = New-Object System.Drawing.Point 360, ($y+3); $lbl.Size = New-Object System.Drawing.Size(580, 25)
        $lbl.ForeColor = $Color_Desc; $lbl.Font = $Font_Desc
        $tooltip.SetToolTip($lbl, $i.D)

        $tab.Controls.Add($chk); $tab.Controls.Add($lbl)
        $dict[$i.Tag] = $chk
        $y += 35
    }
    return $dict
}

# --- 7. NOI DUNG (GIU NGUYEN NHU CU) ---
$chkBasic = Add-TaskItem $tabBasic @(
    @{T="Dọn thư mục Temp"; Tag="TempFiles"; D="Xóa các file rác (.tmp, .log) do phần mềm tạo ra khi chạy."},
    @{T="Dọn Thùng rác"; Tag="RecycleBin"; D="Làm sạch hoàn toàn các file đang nằm trong Thùng rác."},
    @{T="Xóa cache trình duyệt"; Tag="BrowserCache"; D="Xóa bộ nhớ đệm Chrome/Edge/Firefox (Giữ Pass)."},
    @{T="Dọn Windows Update Cache"; Tag="WinUpdateCache"; D="Xóa các file Update cũ (Giải phóng 5-10GB)."},
    @{T="Xóa file Prefetch"; Tag="Prefetch"; D="Xóa bộ đệm khởi động cũ."},
    @{T="Xóa bản tải xuống cũ"; Tag="OldDownloads"; D="Xóa file trong Downloads cũ hơn 30 ngày."},
    @{T="Dọn Event Logs"; Tag="EventLogs"; D="Xóa nhật ký lỗi hệ thống."},
    @{T="Dọn thumbnail cache"; Tag="ThumbnailCache"; D="Sửa lỗi icon bị trắng."}
) $true

$chkAdv = Add-TaskItem $tabAdv @(
    @{T="Dọn dẹp WinSxS (Sâu)"; Tag="WinSxS"; D="Phân tích sâu và xóa thành phần Win thừa (Rất lâu, Anti-Freeze ON)."},
    @{T="Reset Microsoft Store"; Tag="StoreCache"; D="Sửa lỗi không tải được ứng dụng Store."},
    @{T="Dọn OneDrive Cache"; Tag="OneDriveCache"; D="Xóa file log và setup tạm của OneDrive."},
    @{T="Tắt Ngủ Đông (Hibernation)"; Tag="Hibernation"; D="Tắt ngủ đông, lấy lại dung lượng ổ C."},
    @{T="Dọn Cache Font"; Tag="FontCache"; D="Sửa lỗi hiển thị font chữ."},
    @{T="Nén hệ thống (CompactOS)"; Tag="CompressNTFS"; D="Nén Win, tiết kiệm 2-4GB (Lâu)."}
) $true

$chkOpt = Add-TaskItem $tabOpt @(
    @{T="Tối ưu hóa khởi động"; Tag="StartupOptimize"; D="Tắt độ trễ khởi động."},
    @{T="Bật chế độ Hiệu suất cao"; Tag="HighPerfPlan"; D="Kích hoạt Ultimate Performance Plan."},
    @{T="Tắt Game DVR (Tăng FPS)"; Tag="DisableGameDVR"; D="Tắt quay phim nền Xbox."},
    @{T="Tắt Phím dính (Sticky Keys)"; Tag="DisableStickyKeys"; D="Tắt hộp thoại Shift 5 lần."},
    @{T="Tối ưu hóa dịch vụ"; Tag="ServiceOptimize"; D="Tắt Fax, Print Spooler, Telemetry..."},
    @{T="Tối ưu hóa Page File"; Tag="PageFileOptimize"; D="Reset bộ nhớ ảo tự động."},
    @{T="Tối ưu hóa Hiệu ứng ảnh"; Tag="VisualPerformance"; D="Tắt hiệu ứng mờ để máy nhanh hơn."},
    @{T="Tối ưu hóa Windows Search"; Tag="SearchOptimize"; D="Rebuild Index tìm kiếm."},
    @{T="Tối ưu hóa Tắt máy"; Tag="ShutdownOptimize"; D="Giảm thời gian chờ ứng dụng treo."}
) $true

$chkSec = Add-TaskItem $tabSec @(
    @{T="Quét Virus Nhanh"; Tag="BasicMalware"; D="Windows Defender Quick Scan."},
    @{T="Hiện đuôi file (Extension)"; Tag="ShowExtensions"; D="Hiển thị .exe, .pdf tránh virus giả mạo."},
    @{T="Tắt Hỗ trợ từ xa"; Tag="DisableRemoteAssist"; D="Chặn Remote Assistance."},
    @{T="Tắt giao thức SMBv1"; Tag="DisableSMB1"; D="Chặn lỗ hổng WannaCry."},
    @{T="Xóa Lịch sử Web"; Tag="BrowserHistory"; D="Xóa lịch sử web đã truy cập."},
    @{T="Kiểm tra Cập nhật Win"; Tag="WindowsUpdate"; D="Mở trình cập nhật Windows."},
    @{T="Kiểm tra Tường lửa"; Tag="EnsureFirewallEnabled"; D="Bật lại Windows Firewall."},
    @{T="Bật Chống phần mềm rác"; Tag="EnablePUAProtection"; D="Chặn ứng dụng tiềm ẩn nguy hiểm (PUA)."}
) $true

$chkPriv = Add-TaskItem $tabPriv @(
    @{T="Tắt Micro (Toàn hệ thống)"; Tag="DisableMicrophone"; D="Vô hiệu hóa Driver Micro."},
    @{T="Tắt Camera (Toàn hệ thống)"; Tag="DisableCamera"; D="Vô hiệu hóa Driver Webcam."},
    @{T="Tắt Cortana & Copilot"; Tag="DisableCortana"; D="Tắt trợ lý ảo AI."},
    @{T="Tắt Gợi ý Start Menu"; Tag="DisableStartSugg"; D="Tắt quảng cáo trong Start Menu."},
    @{T="Tắt Thông báo Feedback"; Tag="DisableFeedback"; D="Chặn cửa sổ hỏi ý kiến người dùng."},
    @{T="Tắt ID Quảng cáo"; Tag="DisableAdvertisingID"; D="Ngăn theo dõi quảng cáo."},
    @{T="Tắt Telemetry (Theo dõi)"; Tag="DisableTelemetryServices"; D="Chặn gửi dữ liệu chẩn đoán."},
    @{T="Xóa Lịch sử Hoạt động"; Tag="ClearActivityHistory"; D="Xóa Timeline hoạt động."},
    @{T="Tắt Theo dõi Vị trí"; Tag="DisableLocationTracking"; D="Vô hiệu hóa GPS."},
    @{T="Tắt Cloud Clipboard"; Tag="DisableCloudClipboard"; D="Ngăn đồng bộ hóa lịch sử clipboard qua cloud."}
) $true

# Winget & Utilities (Giu nguyen)
$lblW = New-Object System.Windows.Forms.Label; $lblW.Text = "CÔNG CỤ CẬP NHẬT PHẦN MỀM TỰ ĐỘNG (WINGET)"; $lblW.Font = $Font_Title; $lblW.AutoSize = $true; $lblW.Location = New-Object System.Drawing.Point(30, 30)
$btnW = New-Object System.Windows.Forms.Button; $btnW.Text = "KIỂM TRA VÀ CẬP NHẬT TẤT CẢ"; $btnW.Size = New-Object System.Drawing.Size(350, 60); $btnW.Location = New-Object System.Drawing.Point(30, 80); $btnW.BackColor = $Color_Green; $btnW.ForeColor = [System.Drawing.Color]::White; $btnW.Font = $Font_Title
$btnW.Add_Click({ 
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Start-Process "winget" -ArgumentList "upgrade --all --include-unknown --accept-source-agreements" -Wait
            [System.Windows.Forms.MessageBox]::Show("Đã cập nhật xong!", "Winget", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Lỗi khi chạy Winget: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Winget chưa được cài đặt trên máy này!`n`nVui lòng cài đặt từ Microsoft Store hoặc GitHub.", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$tabWinget.Controls.Add($lblW); $tabWinget.Controls.Add($btnW)

$col1_X = 40; $col2_X = 500; $yStart = 40; $yStep = 85
$utils = @(@{T="Disk Cleanup"; Tag="DiskMgr"; D="Mở công cụ dọn dẹp Windows."}, @{T="Xóa Cache DNS"; Tag="FlushDnsCache"; D="Xóa bộ nhớ đệm phân giải tên miền."}, @{T="Sức khỏe Ổ cứng"; Tag="ChkDsk"; D="Xem SMART ổ cứng."}, @{T="Quản lý Khởi động"; Tag="StartupManager"; D="Mở Task Manager."}, @{T="💾 Sao lưu Registry"; Tag="RegBack"; D="Sao lưu HKLM và HKCU vào Desktop."}, @{T="Phân vùng Ổ đĩa"; Tag="DiskPart"; D="Mở Disk Management."}, @{T="Reset Mạng"; Tag="ResetNetworkStack"; D="Reset Winsock và TCP/IP (cần khởi động lại)."}, @{T="Sửa lỗi Win (SFC)"; Tag="FixCommonIssues"; D="Chạy SFC Scannow."}, @{T="🔄 Khởi động lại Card mạng"; Tag="RestartActiveAdapter"; D="Tắt/bật card mạng đang hoạt động."}, @{T="⏰ Dọn dẹp tự động"; Tag="ScheduledCleanup"; D="Thiết lập lịch dọn dẹp hàng tuần."})
for ($utilIndex=0; $utilIndex -lt $utils.Count; $utilIndex++) {
    $utilItem = $utils[$utilIndex]; $row = [math]::Floor($utilIndex / 2); $isCol2 = ($utilIndex % 2 -eq 1); $posX = if ($isCol2) { $col2_X } else { $col1_X }; $posY = $yStart + ($row * $yStep)
    $btnUtil = New-Object System.Windows.Forms.Button; $btnUtil.Text = $utilItem.T; $btnUtil.Location = New-Object System.Drawing.Point($posX, $posY); $btnUtil.Size = New-Object System.Drawing.Size(250, 40); $btnUtil.Tag = $utilItem.Tag; $btnUtil.FlatStyle = "Standard"; $btnUtil.BackColor = [System.Drawing.Color]::White; $btnUtil.Font = $Font_Title
    $lblUtil = New-Object System.Windows.Forms.Label; $lblUtil.Text = $utilItem.D; $lblUtil.Location = New-Object System.Drawing.Point $posX, ($posY+42); $lblUtil.AutoSize = $true; $lblUtil.ForeColor = $Color_Desc; $lblUtil.Font = $Font_Desc
    $tabUtils.Controls.Add($btnUtil); $tabUtils.Controls.Add($lblUtil)
    $btnUtil.Add_Click({ 
        $utilTag = $this.Tag
        switch($utilTag){ 
            "DiskMgr" { Start-Process cleanmgr }
            "FlushDnsCache" { 
                try {
                    $output = ipconfig /flushdns | Out-String
                    Write-CleanupLog "DNS Cache: $output"
                    [System.Windows.Forms.MessageBox]::Show("[OK] Đã xóa DNS Cache thành công!`n`n$output", "Thành công", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } catch {
                    Write-CleanupLog "Lỗi FlushDns: $($_.Exception.Message)"
                    [System.Windows.Forms.MessageBox]::Show("[ERROR] Lỗi: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            "RegBack" { 
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $backupPathHKLM = "$env:USERPROFILE\Desktop\RegBackup_${timestamp}_HKLM.reg"
                $backupPathHKCU = "$env:USERPROFILE\Desktop\RegBackup_${timestamp}_HKCU.reg"
                $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Đang sao lưu Registry...`n")
                $logBox.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Đang sao lưu HKLM\SOFTWARE...`n")
                    $logBox.ScrollToCaret()
                    [System.Windows.Forms.Application]::DoEvents()
                    $proc1 = Start-Process reg -ArgumentList "export `"HKLM\SOFTWARE`" `"$backupPathHKLM`"" -Wait -PassThru -NoNewWindow
                    
                    $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [INFO] Đang sao lưu HKCU...`n")
                    $logBox.ScrollToCaret()
                    [System.Windows.Forms.Application]::DoEvents()
                    $proc2 = Start-Process reg -ArgumentList "export HKCU `"$backupPathHKCU`"" -Wait -PassThru -NoNewWindow
                    
                    $successMsg = ""
                    if ($proc1.ExitCode -eq 0 -and (Test-Path $backupPathHKLM)) {
                        $successMsg += "✅ HKLM: $backupPathHKLM`n"
                        Write-CleanupLog "Registry HKLM backup thành công: $backupPathHKLM"
                    }
                    if ($proc2.ExitCode -eq 0 -and (Test-Path $backupPathHKCU)) {
                        $successMsg += "✅ HKCU: $backupPathHKCU"
                        Write-CleanupLog "Registry HKCU backup thành công: $backupPathHKCU"
                    }
                    
                    if ($successMsg) {
                        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Sao lưu Registry hoàn tất`n")
                        $logBox.ScrollToCaret()
                        [System.Windows.Forms.MessageBox]::Show("[OK] Backup thành công!`n`n$successMsg", "Thành công", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("[ERROR] Backup thất bại!", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                        Write-CleanupLog "Registry backup thất bại"
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("[ERROR] Lỗi: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    Write-CleanupLog "Lỗi Registry backup: $($_.Exception.Message)"
                }
            }
            "ChkDsk" { 
                try {
                    # Detect if running in Sandbox
                    $isSandbox = $env:USERNAME -eq "WDAGUtilityAccount"
                    
                    if ($isSandbox) {
                        [System.Windows.Forms.MessageBox]::Show(
                            "Bạn đang chạy trong Windows Sandbox - không có ổ cứng vật lý.`n`nChức năng này chỉ hoạt động trên máy thật.", 
                            "Windows Sandbox", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information
                        )
                        Write-CleanupLog "Bỏ qua ChkDsk - đang chạy trong Sandbox"
                    } else {
                        $disks = Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, HealthStatus, Size, MediaType
                        
                        if ($disks) {
                            $output = "=== SỨC KHỎE Ổ CỨNG ===`n`n"
                            foreach ($disk in $disks) {
                                $sizeGB = [math]::Round($disk.Size / 1GB, 2)
                                $output += "📀 $($disk.FriendlyName)`n"
                                $output += "   Trạng thái: $($disk.HealthStatus)`n"
                                $output += "   Dung lượng: $sizeGB GB`n"
                                $output += "   Loại: $($disk.MediaType)`n`n"
                            }
                            
                            [System.Windows.Forms.MessageBox]::Show(
                                $output, 
                                "Sức khỏe ổ cứng", 
                                [System.Windows.Forms.MessageBoxButtons]::OK, 
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            )
                            Write-CleanupLog "Đã kiểm tra $($disks.Count) ổ cứng"
                        } else {
                            [System.Windows.Forms.MessageBox]::Show(
                                "Không tìm thấy ổ cứng vật lý trên hệ thống này.", 
                                "Thông báo", 
                                [System.Windows.Forms.MessageBoxButtons]::OK, 
                                [System.Windows.Forms.MessageBoxIcon]::Warning
                            )
                            Write-CleanupLog "Không tìm thấy Physical Disk"
                        }
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Không thể lấy thông tin ổ cứng.`n`nLỗi: $($_.Exception.Message)`n`nĐảm bảo bạn đang chạy với quyền Administrator.", 
                        "Lỗi", 
                        [System.Windows.Forms.MessageBoxButtons]::OK, 
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                    Write-CleanupLog "Lỗi ChkDsk: $($_.Exception.Message)"
                }
            }
            "ResetNetworkStack" { 
                $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có chắc muốn reset cấu hình mạng?`n`nHành động này sẽ:`n- Reset Winsock`n- Reset TCP/IP`n`nSau khi hoàn tất CẦN KHỞI ĐỘNG LẠI máy.", "Xác nhận", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                    try {
                        Write-CleanupLog "Đang reset Winsock..."
                        Start-Process netsh -ArgumentList "winsock reset" -Wait -NoNewWindow
                        Write-CleanupLog "Đang reset TCP/IP..."
                        Start-Process netsh -ArgumentList "int ip reset" -Wait -NoNewWindow
                        Write-CleanupLog "Reset mạng hoàn tất - cần khởi động lại"
                        [System.Windows.Forms.MessageBox]::Show("[OK] Đã reset cài đặt mạng!`n`nVui lòng KHỞI ĐỘNG LẠI máy tính để hoàn tất.", "Thành công", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    } catch {
                        Write-CleanupLog "Lỗi reset mạng: $($_.Exception.Message)"
                        [System.Windows.Forms.MessageBox]::Show("[ERROR] Lỗi: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    }
                }
            }
            "RestartActiveAdapter" {
                try {
                    # Find the active network adapter with default gateway
                    $activeConfig = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -or $_.IPv6DefaultGateway -ne $null} | Select-Object -First 1
                    $activeAdapter = $null
                    
                    if ($activeConfig) {
                        $activeAdapter = Get-NetAdapter | Where-Object {$_.InterfaceIndex -eq $activeConfig.InterfaceIndex} | Select-Object -First 1
                    }
                    
                    # Fallback: find first Up adapter that is Ethernet or WiFi
                    if (-not $activeAdapter) {
                        $activeAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and ($_.MediaType -match 'Ethernet' -or $_.MediaType -match 'Native 802.11') -and $_.InterfaceDescription -notmatch 'Loopback|Virtual|VPN|Bluetooth'} | Select-Object -First 1
                    }
                    
                    if ($activeAdapter) {
                        $adapterName = $activeAdapter.Name
                        $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có muốn khởi động lại card mạng '$adapterName'?`n`n(Kết nối mạng sẽ tạm thời bị gián đoạn)", "Xác nhận", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                        
                        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                            Write-CleanupLog "Đang tắt card mạng: $adapterName"
                            Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
                            Start-Sleep -Seconds 2
                            Write-CleanupLog "Đang bật card mạng: $adapterName"
                            Enable-NetAdapter -Name $adapterName -ErrorAction Stop
                            Write-CleanupLog "Đã khởi động lại card mạng: $adapterName"
                            [System.Windows.Forms.MessageBox]::Show("[OK] Đã khởi động lại card mạng '$adapterName' thành công!", "Thành công", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        }
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Không tìm thấy card mạng đang hoạt động.", "Thông báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                        Write-CleanupLog "Không tìm thấy card mạng đang hoạt động"
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("[ERROR] Lỗi: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    Write-CleanupLog "Lỗi khởi động lại card mạng: $($_.Exception.Message)"
                }
            }
            "ScheduledCleanup" {
                try {
                    $taskName = "WindowsCleanupTool_Auto"
                    $scriptPath = $PSCommandPath
                    
                    # Check if task already exists
                    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                    
                    if ($existingTask) {
                        $updateConfirm = [System.Windows.Forms.MessageBox]::Show("Tác vụ dọn dẹp tự động '$taskName' đã tồn tại.`n`nBạn có muốn cập nhật không?", "Tác vụ đã tồn tại", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                        if ($updateConfirm -eq [System.Windows.Forms.DialogResult]::No) {
                            return
                        }
                        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                        Write-CleanupLog "Đã xóa tác vụ cũ: $taskName"
                    }
                    
                    # Create scheduled task
                    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -AutoRun"
                    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "2:00AM"
                    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
                    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                    
                    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Tự động chạy WindowsCleanupTool hàng tuần vào 2:00 AM Chủ Nhật" | Out-Null
                    
                    Write-CleanupLog "Đã tạo Scheduled Task: $taskName - chạy vào 2:00 AM mỗi Chủ Nhật"
                    [System.Windows.Forms.MessageBox]::Show("[OK] Đã thiết lập dọn dẹp tự động!`n`nTên tác vụ: $taskName`nThời gian: 2:00 AM mỗi Chủ Nhật`nQuyền: SYSTEM", "Thành công", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("[ERROR] Lỗi tạo Scheduled Task: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    Write-CleanupLog "Lỗi tạo Scheduled Task: $($_.Exception.Message)"
                }
            }
            "StartupManager" { Start-Process taskmgr }
            "FixCommonIssues" { Start-Process sfc -ArgumentList "/scannow" }
            "DiskPart" { Start-Process diskmgmt.msc }
        }
    })
}

# --- SYSTEM INFO ---
$infoPanel = New-Object System.Windows.Forms.Panel; $infoPanel.Size = New-Object System.Drawing.Size(965, 80); $infoPanel.Location = New-Object System.Drawing.Point(10, 550); $infoPanel.BackColor = [System.Drawing.Color]::WhiteSmoke; $infoPanel.BorderStyle = "FixedSingle"
$os = (Get-CimInstance Win32_OperatingSystem).Caption; $cpu = (Get-CimInstance Win32_Processor).Name; $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select @{N='Free';E={[math]::Round($_.FreeSpace/1GB,2)}}, @{N='Total';E={[math]::Round($_.Size/1GB,2)}}
$lblLeft = New-Object System.Windows.Forms.Label; $lblLeft.Text = "HỆ ĐIỀU HÀNH: $os`nCPU: $cpu`nRAM: $ram GB"; $lblLeft.Location = New-Object System.Drawing.Point(10, 10); $lblLeft.Size = New-Object System.Drawing.Size(450, 60); $lblLeft.Font = $Font_Normal; $infoPanel.Controls.Add($lblLeft)
$lblRight = New-Object System.Windows.Forms.Label; $lblRight.Text = "Ổ C (HỆ THỐNG):`nTrống: $($disk.Free) GB / Tổng: $($disk.Total) GB"; $lblRight.Location = New-Object System.Drawing.Point(500, 10); $lblRight.Size = New-Object System.Drawing.Size(450, 60); $lblRight.Font = $Font_Title; $lblRight.TextAlign = "TopRight"; $infoPanel.Controls.Add($lblRight)
$form.Controls.Add($infoPanel)

# --- FOOTER ---
$footerPanel = New-Object System.Windows.Forms.Panel; $footerPanel.Size = New-Object System.Drawing.Size(1000, 110); $footerPanel.Location = New-Object System.Drawing.Point(0, 640); $footerPanel.BackColor = [System.Drawing.Color]::White
$logBox = New-Object System.Windows.Forms.RichTextBox; $logBox.Location = New-Object System.Drawing.Point(15, 10); $logBox.Size = New-Object System.Drawing.Size(700, 90); $logBox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular); $logBox.ReadOnly = $true; $logBox.BorderStyle = "FixedSingle"; $logBox.DetectUrls = $false; $footerPanel.Controls.Add($logBox)
$btnRun = New-Object System.Windows.Forms.Button; $btnRun.Text = "BẮT ĐẦU THỰC HIỆN"; $btnRun.Location = New-Object System.Drawing.Point(730, 10); $btnRun.Size = New-Object System.Drawing.Size(240, 50); $btnRun.BackColor = $Color_Accent; $btnRun.ForeColor = [System.Drawing.Color]::White; $btnRun.Font = $Font_Title; $btnRun.FlatStyle = "Flat"; $footerPanel.Controls.Add($btnRun)
$prog = New-Object System.Windows.Forms.ProgressBar; $prog.Location = New-Object System.Drawing.Point(730, 70); $prog.Size = New-Object System.Drawing.Size(240, 20); $footerPanel.Controls.Add($prog)
$form.Controls.Add($footerPanel)

# --- LINK MAIN BUTTON ---
$btnRun.Add_Click({ 
    $allTasks = @{}
    $tabControl.TabPages | ForEach-Object { 
        $_.Controls | Where-Object {
            $_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked
        } | ForEach-Object { 
            $allTasks[$_.Tag] = $_.Text 
        } 
    }
    & $CoreLogic $allTasks 
})

# === REGISTRY CLEANER TAB UI ===
$lblRegTitle = New-Object System.Windows.Forms.Label
$lblRegTitle.Text = "QUÉT VÀ DỌN DẸP REGISTRY"
$lblRegTitle.Font = $Font_Title
$lblRegTitle.AutoSize = $true
$lblRegTitle.Location = New-Object System.Drawing.Point(20, 15)
$tabRegistry.Controls.Add($lblRegTitle)

$btnScanReg = New-Object System.Windows.Forms.Button
$btnScanReg.Text = "QUÉT REGISTRY"
$btnScanReg.Location = New-Object System.Drawing.Point(20, 45)
$btnScanReg.Size = New-Object System.Drawing.Size(150, 40)
$btnScanReg.BackColor = $Color_Accent
$btnScanReg.ForeColor = [System.Drawing.Color]::White
$btnScanReg.FlatStyle = "Flat"
$btnScanReg.Font = $Font_Title
$tabRegistry.Controls.Add($btnScanReg)

$btnCleanReg = New-Object System.Windows.Forms.Button
$btnCleanReg.Text = "DỌN DẸP REGISTRY"
$btnCleanReg.Location = New-Object System.Drawing.Point(180, 45)
$btnCleanReg.Size = New-Object System.Drawing.Size(180, 40)
$btnCleanReg.BackColor = $Color_Green
$btnCleanReg.ForeColor = [System.Drawing.Color]::White
$btnCleanReg.FlatStyle = "Flat"
$btnCleanReg.Font = $Font_Title
$btnCleanReg.Enabled = $false
$tabRegistry.Controls.Add($btnCleanReg)

$lblRegCount = New-Object System.Windows.Forms.Label
$lblRegCount.Text = "Số lỗi tìm thấy: 0"
$lblRegCount.Font = $Font_Normal
$lblRegCount.Location = New-Object System.Drawing.Point(380, 55)
$lblRegCount.Size = New-Object System.Drawing.Size(200, 25)
$tabRegistry.Controls.Add($lblRegCount)

$lstRegIssues = New-Object System.Windows.Forms.ListBox
$lstRegIssues.Location = New-Object System.Drawing.Point(20, 95)
$lstRegIssues.Size = New-Object System.Drawing.Size(900, 200)
$lstRegIssues.Font = $Font_Desc
$lstRegIssues.BorderStyle = "FixedSingle"
$lstRegIssues.SelectionMode = "MultiExtended"
$tabRegistry.Controls.Add($lstRegIssues)

$btnScanReg.Add_Click({
    $this.Enabled = $false
    $this.Text = "Đang quét..."
    $lstRegIssues.Items.Clear()
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $global:RegIssues = Scan-RegistryIssues
        
        foreach ($issue in $global:RegIssues) {
            $lstRegIssues.Items.Add("[$($issue.Type)] $($issue.Description)")
        }
        
        $lblRegCount.Text = "Số lỗi tìm thấy: $($global:RegIssues.Count)"
        
        if ($global:RegIssues.Count -gt 0) {
            $btnCleanReg.Enabled = $true
        } else {
            $lstRegIssues.Items.Add("[OK] Không tìm thấy lỗi Registry!")
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Lỗi khi quét: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    
    $this.Text = "QUÉT REGISTRY"
    $this.Enabled = $true
})

$btnCleanReg.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có chắc muốn dọn dẹp $($global:RegIssues.Count) lỗi Registry?`n`nRegistry sẽ được sao lưu trước khi dọn dẹp.", "Xác nhận", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $this.Enabled = $false
        $this.Text = "Đang dọn..."
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $cleaned = Clean-RegistryIssues -Issues $global:RegIssues
            [System.Windows.Forms.MessageBox]::Show("[OK] Đã dọn dẹp $cleaned lỗi Registry!`n`nFile backup đã được lưu trên Desktop.", "Hoàn thành", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            
            $lstRegIssues.Items.Clear()
            $global:RegIssues = @()
            $lblRegCount.Text = "Số lỗi tìm thấy: 0"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Lỗi khi dọn dẹp: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        
        $this.Text = "DỌN DẸP REGISTRY"
        $this.Enabled = $false
    }
})

# === DUPLICATE FILE FINDER TAB UI ===
$lblDupTitle = New-Object System.Windows.Forms.Label
$lblDupTitle.Text = "TÌM VÀ XÓA FILE TRÙNG LẶP"
$lblDupTitle.Font = $Font_Title
$lblDupTitle.AutoSize = $true
$lblDupTitle.Location = New-Object System.Drawing.Point(20, 15)
$tabDuplicates.Controls.Add($lblDupTitle)

$lblDupPath = New-Object System.Windows.Forms.Label
$lblDupPath.Text = "Thư mục quét:"
$lblDupPath.Font = $Font_Normal
$lblDupPath.Location = New-Object System.Drawing.Point(20, 50)
$lblDupPath.Size = New-Object System.Drawing.Size(100, 25)
$tabDuplicates.Controls.Add($lblDupPath)

$txtDupPath = New-Object System.Windows.Forms.TextBox
$txtDupPath.Text = "$env:USERPROFILE"
$txtDupPath.Location = New-Object System.Drawing.Point(120, 48)
$txtDupPath.Size = New-Object System.Drawing.Size(450, 25)
$txtDupPath.Font = $Font_Normal
$tabDuplicates.Controls.Add($txtDupPath)

$btnBrowseDup = New-Object System.Windows.Forms.Button
$btnBrowseDup.Text = "Duyệt..."
$btnBrowseDup.Location = New-Object System.Drawing.Point(580, 46)
$btnBrowseDup.Size = New-Object System.Drawing.Size(80, 28)
$btnBrowseDup.Font = $Font_Desc
$tabDuplicates.Controls.Add($btnBrowseDup)

$btnScanDup = New-Object System.Windows.Forms.Button
$btnScanDup.Text = "QUÉT FILE TRÙNG"
$btnScanDup.Location = New-Object System.Drawing.Point(670, 45)
$btnScanDup.Size = New-Object System.Drawing.Size(150, 35)
$btnScanDup.BackColor = $Color_Accent
$btnScanDup.ForeColor = [System.Drawing.Color]::White
$btnScanDup.FlatStyle = "Flat"
$btnScanDup.Font = $Font_Title
$tabDuplicates.Controls.Add($btnScanDup)

$lblDupStats = New-Object System.Windows.Forms.Label
$lblDupStats.Text = "Nhóm trùng: 0 | Dung lượng có thể giải phóng: 0 MB"
$lblDupStats.Font = $Font_Normal
$lblDupStats.Location = New-Object System.Drawing.Point(20, 85)
$lblDupStats.Size = New-Object System.Drawing.Size(500, 25)
$tabDuplicates.Controls.Add($lblDupStats)

$lstDuplicates = New-Object System.Windows.Forms.ListView
$lstDuplicates.Location = New-Object System.Drawing.Point(20, 115)
$lstDuplicates.Size = New-Object System.Drawing.Size(900, 150)
$lstDuplicates.View = "Details"
$lstDuplicates.FullRowSelect = $true
$lstDuplicates.CheckBoxes = $true
$lstDuplicates.Font = $Font_Desc
$lstDuplicates.Columns.Add("Tên File", 200)
$lstDuplicates.Columns.Add("Kích thước", 100)
$lstDuplicates.Columns.Add("Đường dẫn", 450)
$lstDuplicates.Columns.Add("Hash", 150)
$tabDuplicates.Controls.Add($lstDuplicates)

$btnDeleteDup = New-Object System.Windows.Forms.Button
$btnDeleteDup.Text = "XÓA FILE ĐÃ CHỌN"
$btnDeleteDup.Location = New-Object System.Drawing.Point(750, 270)
$btnDeleteDup.Size = New-Object System.Drawing.Size(170, 35)
$btnDeleteDup.BackColor = [System.Drawing.Color]::IndianRed
$btnDeleteDup.ForeColor = [System.Drawing.Color]::White
$btnDeleteDup.FlatStyle = "Flat"
$btnDeleteDup.Font = $Font_Title
$btnDeleteDup.Enabled = $false
$tabDuplicates.Controls.Add($btnDeleteDup)

$btnBrowseDup.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Chọn thư mục để quét file trùng lặp"
    $folderBrowser.SelectedPath = $txtDupPath.Text
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDupPath.Text = $folderBrowser.SelectedPath
    }
})

$btnScanDup.Add_Click({
    if (!(Test-Path $txtDupPath.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Đường dẫn không hợp lệ!", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    $this.Enabled = $false
    $this.Text = "Đang quét..."
    $lstDuplicates.Items.Clear()
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $global:DuplicateFiles = Find-DuplicateFiles -ScanPath $txtDupPath.Text -MinSizeMB 1
        
        $totalPotentialFreed = 0
        foreach ($dup in $global:DuplicateFiles) {
            $filesToShow = $dup.Files
            $isFirst = $true
            foreach ($file in $filesToShow) {
                if (Test-Path $file -ErrorAction SilentlyContinue) {
                    $fileInfo = Get-Item $file -ErrorAction SilentlyContinue
                    if ($fileInfo) {
                        $item = New-Object System.Windows.Forms.ListViewItem($fileInfo.Name)
                        $item.SubItems.Add("$([math]::Round($fileInfo.Length / 1MB, 2)) MB")
                        $item.SubItems.Add($file)
                        $item.SubItems.Add($dup.Hash.Substring(0, 8) + "...")
                        $item.Tag = $file
                        
                        if ($isFirst) {
                            $item.BackColor = [System.Drawing.Color]::LightGreen
                            $isFirst = $false
                        } else {
                            $item.Checked = $true
                            $totalPotentialFreed += $fileInfo.Length
                        }
                        
                        $lstDuplicates.Items.Add($item)
                    }
                }
            }
        }
        
        $lblDupStats.Text = "Nhóm trùng: $($global:DuplicateFiles.Count) | Dung lượng có thể giải phóng: $([math]::Round($totalPotentialFreed / 1MB, 2)) MB"
        
        if ($global:DuplicateFiles.Count -gt 0) {
            $btnDeleteDup.Enabled = $true
        } else {
            $lstDuplicates.Items.Clear()
            $item = New-Object System.Windows.Forms.ListViewItem("[OK] Không tìm thấy file trùng lặp!")
            $lstDuplicates.Items.Add($item)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Lỗi khi quét: $($_.Exception.Message)", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    
    $this.Text = "QUÉT FILE TRÙNG"
    $this.Enabled = $true
})

$btnDeleteDup.Add_Click({
    $filesToDelete = @()
    foreach ($item in $lstDuplicates.CheckedItems) {
        if ($item.Tag) {
            $filesToDelete += $item.Tag
        }
    }
    
    if ($filesToDelete.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Vui lòng chọn file cần xóa!", "Thông báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có chắc muốn xóa $($filesToDelete.Count) file trùng lặp?", "Xác nhận", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $result = Remove-DuplicateFiles -FilesToDelete $filesToDelete
        [System.Windows.Forms.MessageBox]::Show("[OK] Đã xóa $($result.DeletedCount) file!`nĐã giải phóng: $($result.FreedMB) MB", "Hoàn thành", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Refresh list
        $lstDuplicates.Items.Clear()
        $global:DuplicateFiles = @()
        $lblDupStats.Text = "Nhóm trùng: 0 | Dung lượng có thể giải phóng: 0 MB"
        $btnDeleteDup.Enabled = $false
    }
})

# === ADVANCED UNINSTALLER TAB UI ===
$lblUninstTitle = New-Object System.Windows.Forms.Label
$lblUninstTitle.Text = "GỠ CÀI ĐẶT ỨNG DỤNG + XÓA FILE THỪA"
$lblUninstTitle.Font = $Font_Title
$lblUninstTitle.AutoSize = $true
$lblUninstTitle.Location = New-Object System.Drawing.Point(20, 15)
$tabUninstaller.Controls.Add($lblUninstTitle)

$lblSearchApp = New-Object System.Windows.Forms.Label
$lblSearchApp.Text = "Tìm kiếm:"
$lblSearchApp.Font = $Font_Normal
$lblSearchApp.Location = New-Object System.Drawing.Point(20, 48)
$lblSearchApp.Size = New-Object System.Drawing.Size(70, 25)
$tabUninstaller.Controls.Add($lblSearchApp)

$txtSearchApp = New-Object System.Windows.Forms.TextBox
$txtSearchApp.Location = New-Object System.Drawing.Point(95, 45)
$txtSearchApp.Size = New-Object System.Drawing.Size(300, 25)
$txtSearchApp.Font = $Font_Normal
$tabUninstaller.Controls.Add($txtSearchApp)

$btnRefreshApps = New-Object System.Windows.Forms.Button
$btnRefreshApps.Text = "Làm mới"
$btnRefreshApps.Location = New-Object System.Drawing.Point(410, 43)
$btnRefreshApps.Size = New-Object System.Drawing.Size(100, 30)
$btnRefreshApps.Font = $Font_Desc
$tabUninstaller.Controls.Add($btnRefreshApps)

$lblAppCount = New-Object System.Windows.Forms.Label
$lblAppCount.Text = "Tổng số ứng dụng: 0"
$lblAppCount.Font = $Font_Normal
$lblAppCount.Location = New-Object System.Drawing.Point(530, 48)
$lblAppCount.Size = New-Object System.Drawing.Size(250, 25)
$tabUninstaller.Controls.Add($lblAppCount)

$lstApps = New-Object System.Windows.Forms.ListView
$lstApps.Location = New-Object System.Drawing.Point(20, 80)
$lstApps.Size = New-Object System.Drawing.Size(900, 180)
$lstApps.View = "Details"
$lstApps.FullRowSelect = $true
$lstApps.Font = $Font_Desc
$lstApps.Columns.Add("Tên ứng dụng", 280)
$lstApps.Columns.Add("Nhà phát hành", 180)
$lstApps.Columns.Add("Phiên bản", 100)
$lstApps.Columns.Add("Kích thước (MB)", 100)
$lstApps.Columns.Add("Ngày cài", 100)
$tabUninstaller.Controls.Add($lstApps)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "GỠ CÀI ĐẶT + XÓA FILE THỪA"
$btnUninstall.Location = New-Object System.Drawing.Point(700, 265)
$btnUninstall.Size = New-Object System.Drawing.Size(220, 35)
$btnUninstall.BackColor = [System.Drawing.Color]::IndianRed
$btnUninstall.ForeColor = [System.Drawing.Color]::White
$btnUninstall.FlatStyle = "Flat"
$btnUninstall.Font = $Font_Title
$tabUninstaller.Controls.Add($btnUninstall)

$LoadApps = {
    $lstApps.Items.Clear()
    [System.Windows.Forms.Application]::DoEvents()
    
    $global:InstalledApps = Get-InstalledApps
    $searchText = $txtSearchApp.Text.ToLower()
    
    $filteredApps = $global:InstalledApps
    if ($searchText) {
        $filteredApps = $global:InstalledApps | Where-Object { $_.Name.ToLower().Contains($searchText) }
    }
    
    foreach ($app in $filteredApps) {
        $item = New-Object System.Windows.Forms.ListViewItem($app.Name)
        $item.SubItems.Add($app.Publisher)
        $item.SubItems.Add($app.Version)
        $item.SubItems.Add($app.EstimatedSize.ToString())
        $item.SubItems.Add($app.InstallDate)
        $item.Tag = $app
        $lstApps.Items.Add($item)
    }
    
    $lblAppCount.Text = "Tổng số ứng dụng: $($filteredApps.Count)"
}

$btnRefreshApps.Add_Click({
    $this.Enabled = $false
    $this.Text = "Đang tải..."
    [System.Windows.Forms.Application]::DoEvents()
    
    & $LoadApps
    
    $this.Text = "Làm mới"
    $this.Enabled = $true
})

$txtSearchApp.Add_TextChanged({
    $searchText = $txtSearchApp.Text.ToLower()
    $lstApps.Items.Clear()
    
    $filteredApps = $global:InstalledApps
    if ($searchText) {
        $filteredApps = $global:InstalledApps | Where-Object { $_.Name.ToLower().Contains($searchText) }
    }
    
    foreach ($app in $filteredApps) {
        $item = New-Object System.Windows.Forms.ListViewItem($app.Name)
        $item.SubItems.Add($app.Publisher)
        $item.SubItems.Add($app.Version)
        $item.SubItems.Add($app.EstimatedSize.ToString())
        $item.SubItems.Add($app.InstallDate)
        $item.Tag = $app
        $lstApps.Items.Add($item)
    }
    
    $lblAppCount.Text = "Tổng số ứng dụng: $($filteredApps.Count)"
})

$btnUninstall.Add_Click({
    if ($lstApps.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Vui lòng chọn ứng dụng cần gỡ!", "Thông báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $selectedApp = $lstApps.SelectedItems[0].Tag
    
    $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có chắc muốn gỡ cài đặt:`n`n$($selectedApp.Name)`n`nỨng dụng sẽ được gỡ bỏ và các file thừa sẽ được xóa.", "Xác nhận gỡ cài đặt", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $this.Enabled = $false
        $this.Text = "Đang gỡ..."
        [System.Windows.Forms.Application]::DoEvents()
        
        $result = Uninstall-AppCompletely -UninstallString $selectedApp.UninstallString -AppName $selectedApp.Name -InstallLocation $selectedApp.InstallLocation
        
        if ($result) {
            [System.Windows.Forms.MessageBox]::Show("[OK] Đã gỡ cài đặt thành công: $($selectedApp.Name)`n`nCác file thừa đã được xóa.", "Hoàn thành", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            & $LoadApps
        } else {
            [System.Windows.Forms.MessageBox]::Show("[WARN] Có lỗi khi gỡ cài đặt. Vui lòng kiểm tra log.", "Cảnh báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        
        $this.Text = "GỠ CÀI ĐẶT + XÓA FILE THỪA"
        $this.Enabled = $true
    }
})

# Load health on form shown
$form.Add_Shown({
    & $UpdateHealthDashboard
    & $LoadApps
})

# --- AUTORUN MODE ---
# When running with -AutoRun parameter (from Scheduled Task), run cleanup automatically without UI
if ($AutoRun) {
    Write-CleanupLog "=== AUTORUN MODE - Chạy tự động từ Scheduled Task ==="
    
    # Select basic cleanup tasks automatically
    $autoTasks = @{
        "TempFiles" = "Dọn thư mục Temp"
        "RecycleBin" = "Dọn Thùng rác"
        "BrowserCache" = "Xóa cache trình duyệt"
        "WinUpdateCache" = "Dọn Windows Update Cache"
        "ThumbnailCache" = "Xóa Thumbnail cache"
    }
    
    Write-CleanupLog "Đang thực hiện các tác vụ dọn dẹp cơ bản..."
    
    foreach ($taskKey in $autoTasks.Keys) {
        $taskName = $autoTasks[$taskKey]
        Write-CleanupLog "Đang xử lý: $taskName"
        
        try {
            switch ($taskKey) {
                "TempFiles" {
                    if (Test-Path "$env:TEMP") {
                        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$env:windir\Temp") {
                        Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-CleanupLog "[OK] Đã xóa Temp files"
                }
                "RecycleBin" {
                    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                    Write-CleanupLog "[OK] Đã dọn Thùng rác"
                }
                "BrowserCache" {
                    $chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                    if (Test-Path $chromeCache) {
                        Remove-Item "$chromeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                    if (Test-Path $edgeCache) {
                        Remove-Item "$edgeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-CleanupLog "[OK] Đã xóa cache trình duyệt"
                }
                "WinUpdateCache" {
                    Stop-Service wuauserv -ErrorAction SilentlyContinue
                    if (Test-Path "$env:windir\SoftwareDistribution\Download") {
                        Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Start-Service wuauserv -ErrorAction SilentlyContinue
                    Write-CleanupLog "[OK] Đã xóa Windows Update Cache"
                }
                "ThumbnailCache" {
                    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer") {
                        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                    }
                    Write-CleanupLog "[OK] Đã xóa Thumbnail cache"
                }
            }
        } catch {
            Write-CleanupLog "[ERROR] Lỗi khi xử lý $taskName : $($_.Exception.Message)"
        }
    }
    
    Write-CleanupLog "=== AUTORUN HOÀN TẤT ==="
    exit 0
}

$form.ShowDialog() | Out-Null