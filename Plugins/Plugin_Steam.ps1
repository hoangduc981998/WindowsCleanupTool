function Get-PluginMetadata {
    return @{
        Name = "Steam Download Cache Cleaner"
        Version = "1.0.0"
        Author = "CleanupTool Team"
        Description = "Xóa cache download Steam (không ảnh hưởng games đã cài)"
        Category = "Game"
        Enabled = $true
    }
}

function Get-CleanupTargets {
    param([switch]$PreviewOnly)
    
    $targets = @()
    
    try {
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction Stop).SteamPath
        $downloadCache = Join-Path $steamPath "appcache\httpcache"
        
        if (Test-Path $downloadCache) {
            Get-ChildItem $downloadCache -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $targets += [PSCustomObject]@{
                    Path = $_.FullName
                    Size = $_.Length
                    Type = "Steam Cache"
                    SafeToDelete = $true
                }
            }
        }
    } catch {}
    
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