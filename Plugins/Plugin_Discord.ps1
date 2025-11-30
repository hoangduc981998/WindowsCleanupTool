function Get-PluginMetadata {
    return @{
        Name = "Discord Cache Cleaner"
        Version = "1.0.0"
        Author = "CleanupTool Team"
        Description = "Xóa cache Discord (Cache, Code Cache, GPUCache)"
        Category = "Communication"
        Enabled = $true
    }
}

function Get-CleanupTargets {
    param([switch]$PreviewOnly)
    
    $targets = @()
    $discordPaths = @(
        "$env:APPDATA\Discord\Cache",
        "$env:APPDATA\Discord\Code Cache",
        "$env:APPDATA\Discord\GPUCache"
    )
    
    foreach ($path in $discordPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $targets += [PSCustomObject]@{
                    Path = $_.FullName
                    Size = $_.Length
                    Type = "Discord Cache"
                    SafeToDelete = $true
                }
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