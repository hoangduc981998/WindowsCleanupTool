function Get-PluginMetadata {
    return @{
        Name = "VSCode Cache Cleaner"
        Version = "1.0.0"
        Author = "CleanupTool Team"
        Description = "Clean VSCode cache (logs, crash dumps, workspace storage)"
        Category = "Development"
        Enabled = $true
    }
}

function Get-CleanupTargets {
    param([switch]$PreviewOnly)
    
    $targets = @()
    $vscodePaths = @(
        "$env:APPDATA\Code\logs",
        "$env:APPDATA\Code\CachedData",
        "$env:APPDATA\Code\CachedExtensions",
        "$env:APPDATA\Code\CrashDumps"
    )
    
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.LastWriteTime -lt (Get-Date).AddDays(-7)) {
                    $targets += [PSCustomObject]@{
                        Path = $_.FullName
                        Size = $_.Length
                        Type = "VSCode Cache"
                        SafeToDelete = $true
                    }
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
                if ($UseQuarantine -and (Get-Command Move-ToQuarantine -ErrorAction SilentlyContinue)) {
                    Move-ToQuarantine -FilePath $target.Path -TaskSource "VSCode Plugin"
                } else {
                    Remove-Item $target.Path -Force
                }
                $cleaned++
                $totalSize += $size
            }
        } catch {
            Write-Warning "Failed to clean $($target.Path): $($_.Exception.Message)"
        }
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
