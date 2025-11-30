# ============================================
# SAFETY & QUARANTINE SYSTEM - Added v2.0
# ============================================

$global:ProtectedPaths = @(
    "$env:SystemRoot",
    "$env:SystemRoot\System32",
    "$env:SystemRoot\SysWOW64",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Pictures",
    "$env:USERPROFILE\Videos",
    "$env:USERPROFILE\Music",
    "$env:USERPROFILE\Desktop"
)

$global:ProtectedExtensions = @('.sys', '.dll', '.exe', '.ini', '.inf')

function Test-SafeToDelete {
    param([string]$FilePath)
    
    foreach ($protectedPath in $global:ProtectedPaths) {
        if ($FilePath.StartsWith($protectedPath, [StringComparison]::OrdinalIgnoreCase)) {
            if ($FilePath -notmatch '\\Temp\\|\\Cache\\|\\Logs\\') {
                Write-CleanupLog "[BLOCKED] Protected path: $FilePath"
                return $false
            }
        }
    }
    
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($ext -in $global:ProtectedExtensions) {
        if ($FilePath -notmatch '\\Temp\\|\\Cache\\') {
            Write-CleanupLog "[BLOCKED] Protected extension: $FilePath"
            return $false
        }
    }
    
    try {
        $file = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
        $file.Close()
        $file.Dispose()
        return $true
    } catch {
        Write-CleanupLog "[SKIP] File in use: $FilePath"
        return $false
    }
}

function Move-ToQuarantine {
    param(
        [string]$FilePath,
        [string]$TaskSource
    )
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $quarantineBase = "$env:LOCALAPPDATA\CleanupTool\Quarantine\$timestamp"
        
        if (!(Test-Path $quarantineBase)) {
            New-Item -ItemType Directory -Path $quarantineBase -Force | Out-Null
        }
        
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $uniqueName = "$([guid]::NewGuid())_$fileName"
        $quarantinePath = Join-Path $quarantineBase $uniqueName
        
        Move-Item -Path $FilePath -Destination $quarantinePath -Force -ErrorAction Stop
        
        $metadata = @{
            OriginalPath = $FilePath
            QuarantineDate = Get-Date
            TaskSource = $TaskSource
            FileSize = (Get-Item $quarantinePath -ErrorAction SilentlyContinue).Length
        }
        $metadata | ConvertTo-Json | Out-File "$quarantinePath.meta.json"
        
        Write-CleanupLog "[QUARANTINE] Moved: $FilePath"
        return $true
    } catch {
        Write-CleanupLog "[ERROR] Quarantine failed: $($_.Exception.Message)"
        return $false
    }
}

function Restore-FromQuarantine {
    param([string]$QuarantinePath)
    
    try {
        $metaFile = "$QuarantinePath.meta.json"
        if (Test-Path $metaFile) {
            $meta = Get-Content $metaFile | ConvertFrom-Json
            $originalPath = $meta.OriginalPath
            
            $parentDir = Split-Path $originalPath -Parent
            if (!(Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            Move-Item -Path $QuarantinePath -Destination $originalPath -Force
            Remove-Item $metaFile -Force
            
            Write-CleanupLog "[RESTORE] $QuarantinePath → $originalPath"
            return $true
        }
    } catch {
        Write-CleanupLog "[ERROR] Restore failed: $($_.Exception.Message)"
    }
    return $false
}

function Clear-OldQuarantine {
    param([int]$DaysOld = 7)
    
    $quarantineBase = "$env:LOCALAPPDATA\CleanupTool\Quarantine"
    if (!(Test-Path $quarantineBase)) { return }
    
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    
    Get-ChildItem $quarantineBase -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.CreationTime -lt $cutoffDate
    } | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-CleanupLog "[CLEANUP] Deleted old quarantine: $($_.Name)"
    }
}

# ============================================
# PLUGIN SYSTEM - Added v2.0
# ============================================

function Load-CleanupPlugins {
    $pluginPath = Join-Path $PSScriptRoot "Plugins"
    
    if (!(Test-Path $pluginPath)) {
        New-Item -ItemType Directory -Path $pluginPath -Force | Out-Null
        Write-CleanupLog "[PLUGIN] Created Plugins folder"
        return @()
    }
    
    $plugins = @()
    
    Get-ChildItem $pluginPath -Filter "Plugin_*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            
            $metadata = Get-PluginMetadata
            
            if ($metadata.Enabled) {
                $plugins += @{
                    FilePath = $_.FullName
                    Metadata = $metadata
                }
                
                Write-CleanupLog "[PLUGIN] Loaded: $($metadata.Name) v$($metadata.Version)"
            }
        } catch {
            Write-CleanupLog "[PLUGIN ERROR] Failed to load: $($_.Name) - $($_.Exception.Message)"
        }
    }
    
    return $plugins
}

# Load plugins on startup
$global:LoadedPlugins = Load-CleanupPlugins