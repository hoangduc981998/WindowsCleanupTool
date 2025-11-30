function Get-PluginMetadata {
    return @{
        Name = "Spotify Cache Cleaner"
        Version = "1.0.0"
        Author = "CleanupTool Team"
        Description = "Dọn cache Spotify (giữ playlists & settings)"
        Category = "Media"
        Enabled = $true
    }
}

function Get-CleanupTargets {
    param([switch]$PreviewOnly)
    
    $targets = @()
    $spotifyCache = "$env:APPDATA\Spotify\Data"
    
    if (Test-Path $spotifyCache) {
        Get-ChildItem $spotifyCache -Include "*.file" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $targets += [PSCustomObject]@{
                Path = $_.FullName
                Size = $_.Length
                Type = "Spotify Cache"
                SafeToDelete = $true
            }
        }
    }
    
    return $targets
}

function Invoke-PluginCleanup {
    param([array]$Targets, [switch]$UseQuarantine = $true)
    
    $cleaned = 0
    $totalSize = 0
    
    foreach ($target in $Targets) {
        try {
            if (Test-Path $target.Path) {
                $size = (Get-Item $target.Path).Length
                Remove-Item $target.Path -Force
                $cleaned++
                $totalSize += $size
            }
        } catch {}
    }
    
    return @{ FilesDeleted = $cleaned; SpaceFreed = $totalSize }
}

function Get-EstimatedSpace {
    $targets = Get-CleanupTargets -PreviewOnly
    $totalSize = ($targets | Measure-Object -Property Size -Sum -ErrorAction SilentlyContinue).Sum
    if (!$totalSize) { $totalSize = 0 }
    return [math]::Round($totalSize / 1MB, 2)
}

Export-ModuleMember -Function *