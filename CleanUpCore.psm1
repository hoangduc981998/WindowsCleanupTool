# CleanUpCore.psm1 - Core logic module for Windows Cleanup Tool

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
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache",
        "$env:LOCALAPPDATA\Opera Software\Opera GX Stable\Cache"
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

# --- SECURE FILE DELETION ---

# Function to securely delete a file by overwriting its content before deletion
function Remove-SecureItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [int]$Passes = 3
    )
    
    try {
        # Verify file existence
        if (-not (Test-Path $Path -PathType Leaf)) {
            Write-CleanupLog "[WARN] Secure delete: File not found - $Path"
            return $false
        }
        
        # Get file size for overwriting
        $fileInfo = Get-Item $Path -ErrorAction Stop
        $fileSize = $fileInfo.Length
        
        # Skip if file is empty
        if ($fileSize -eq 0) {
            Remove-Item -Path $Path -Force -ErrorAction Stop
            return $true
        }
        
        # Use chunked writing for large files to prevent memory issues
        $chunkSize = 1MB
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        
        # Overwrite file content multiple passes
        for ($pass = 1; $pass -le $Passes; $pass++) {
            try {
                $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
                try {
                    $bytesRemaining = $fileSize
                    while ($bytesRemaining -gt 0) {
                        $currentChunkSize = [math]::Min($chunkSize, $bytesRemaining)
                        $randomBytes = New-Object byte[] $currentChunkSize
                        $rng.GetBytes($randomBytes)
                        $fileStream.Write($randomBytes, 0, $currentChunkSize)
                        $bytesRemaining -= $currentChunkSize
                    }
                } finally {
                    $fileStream.Close()
                    $fileStream.Dispose()
                }
            } catch {
                Write-CleanupLog "[WARN] Secure delete pass $pass failed for: $Path - $($_.Exception.Message)"
            }
        }
        
        # Clean up RNG
        $rng.Dispose()
        
        # Finally delete the file
        Remove-Item -Path $Path -Force -ErrorAction Stop
        Write-CleanupLog "[OK] Securely deleted: $Path"
        return $true
    } catch {
        Write-CleanupLog "[ERROR] Secure delete failed: $Path - $($_.Exception.Message)"
        return $false
    }
}

# --- BROWSER CACHE CLEANING ---

# Function to clean browser caches with enhanced browser detection
function Clean-BrowserCache {
    [CmdletBinding()]
    param()
    
    $cleanedBrowsersHash = @{}
    $results = @{
        CleanedBrowsers = @()
        Errors = @()
        TotalFilesDeleted = 0
    }
    
    # Define browser cache paths
    $browserCachePaths = @{
        "Google Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "Microsoft Edge" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        "Mozilla Firefox" = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
        "Brave" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
        "Opera" = "$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache"
        "Opera GX" = "$env:LOCALAPPDATA\Opera Software\Opera GX Stable\Cache"
    }
    
    # Stop browser processes first (include all known process names)
    try {
        Stop-Process -Name chrome, msedge, firefox, brave, opera, opera_gx -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    } catch {
        # Ignore errors when stopping processes
    }
    
    Write-CleanupLog "[INFO] Starting browser cache cleanup..."
    
    foreach ($browser in $browserCachePaths.Keys) {
        $cachePath = $browserCachePaths[$browser]
        
        try {
            # Handle wildcard paths (Firefox profiles)
            if ($cachePath -like "*\*\*") {
                $resolvedPaths = Resolve-Path $cachePath -ErrorAction SilentlyContinue
                if ($resolvedPaths) {
                    foreach ($resolvedPath in $resolvedPaths) {
                        $filesDeleted = Clean-CacheDirectory -CachePath $resolvedPath.Path -BrowserName $browser
                        $results.TotalFilesDeleted += $filesDeleted
                        if ($filesDeleted -gt 0 -and -not $cleanedBrowsersHash.ContainsKey($browser)) {
                            $cleanedBrowsersHash[$browser] = $true
                        }
                    }
                }
            } else {
                if (Test-Path $cachePath) {
                    $filesDeleted = Clean-CacheDirectory -CachePath $cachePath -BrowserName $browser
                    $results.TotalFilesDeleted += $filesDeleted
                    if ($filesDeleted -gt 0 -and -not $cleanedBrowsersHash.ContainsKey($browser)) {
                        $cleanedBrowsersHash[$browser] = $true
                    }
                }
            }
        } catch {
            $results.Errors += "Error cleaning $browser cache: $($_.Exception.Message)"
            Write-CleanupLog "[ERROR] $browser cache cleanup failed: $($_.Exception.Message)"
        }
    }
    
    # Convert hashtable keys to array for the result
    $results.CleanedBrowsers = @($cleanedBrowsersHash.Keys)
    
    Write-CleanupLog "[OK] Browser cache cleanup completed. Deleted $($results.TotalFilesDeleted) files from $($results.CleanedBrowsers.Count) browsers."
    
    return $results
}

# Helper function to clean a specific cache directory
function Clean-CacheDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CachePath,
        
        [Parameter(Mandatory = $true)]
        [string]$BrowserName
    )
    
    $deletedCount = 0
    
    if (-not (Test-Path $CachePath)) {
        return $deletedCount
    }
    
    # Verify this is a safe path before deletion
    if (-not (Test-SafePath -Path $CachePath)) {
        Write-CleanupLog "[WARN] Skipping unsafe path: $CachePath"
        return $deletedCount
    }
    
    try {
        $files = Get-ChildItem -Path $CachePath -Recurse -File -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                $deleted = Remove-SecureItem -Path $file.FullName -Passes 1
                if ($deleted) {
                    $deletedCount++
                }
            } catch {
                # Try normal delete if secure delete fails
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $deletedCount++
                } catch {
                    # File might be in use, skip it
                }
            }
        }
        
        # Also remove empty directories
        $directories = Get-ChildItem -Path $CachePath -Recurse -Directory -ErrorAction SilentlyContinue | 
                       Sort-Object { $_.FullName.Length } -Descending
        
        foreach ($dir in $directories) {
            try {
                if ((Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                    Remove-Item -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Directory might not be empty or in use
            }
        }
        
        Write-CleanupLog "[OK] Cleaned $BrowserName cache: $deletedCount files deleted from $CachePath"
    } catch {
        Write-CleanupLog "[WARN] Error cleaning $BrowserName cache at $CachePath: $($_.Exception.Message)"
    }
    
    return $deletedCount
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
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [OK] Da tao Restore Point`n")
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

# Export all functions
Export-ModuleMember -Function *
