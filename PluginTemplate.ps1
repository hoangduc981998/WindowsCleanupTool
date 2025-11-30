# Plugin Template for WindowsCleanupTool
function Get-PluginMetadata {
    return @{
        Name = "Plugin Name"
        Version = "1.0.0"
        Author = "Your Name"
        Description = "Plugin description"
        Category = "Browser"
        Enabled = $true
    }
}

function Get-CleanupTargets {
    param([switch]$PreviewOnly)
    $targets = @()
    $cachePath = "$env:APPDATA\YourApp\Cache"
    if (Test-Path $cachePath) {
        Get-ChildItem $cachePath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $targets += [PSCustomObject]@{
                Path = $_.FullName
                Size = $_.Length
                Type = "Cache"
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
                $size = (Get-Item $target.Path -ErrorAction SilentlyContinue).Length
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