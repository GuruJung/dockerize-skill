[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AgentsRoot = (Join-Path $HOME '.agents')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ExistingItem {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $parent = Split-Path -Parent $LiteralPath
    $leaf = Split-Path -Leaf $LiteralPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $parent -Force |
        Where-Object { $_.Name -ceq $leaf } |
        Select-Object -First 1
}

function Assert-ManagedDirectory {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $item = Get-ExistingItem -LiteralPath $LiteralPath
    if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to use reparse-point directory: $LiteralPath"
    }
}

function New-BackupPath {
    param([Parameter(Mandatory = $true)][string]$Root)

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $sequence = 0
    foreach ($item in (Get-ChildItem -LiteralPath $Root -Force)) {
        if ($item.Name -match ('^{0}-(\d{{6}})-' -f [Regex]::Escape($stamp))) {
            $existingSequence = [int]$Matches[1]
            if ($existingSequence -ge $sequence) {
                $sequence = $existingSequence + 1
            }
        }
    }
    do {
        $candidate = Join-Path $Root ("{0}-{1:D6}-uninstall" -f $stamp, $sequence)
        $sequence += 1
    } while ($null -ne (Get-ExistingItem -LiteralPath $candidate))
    return $candidate
}

function Remove-ExpiredBackups {
    param([Parameter(Mandatory = $true)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return
    }
    $backups = @(Get-ChildItem -LiteralPath $Root -Force |
        Where-Object {
            $_.PSIsContainer -and
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
            $_.Name -match '^\d{8}T\d{6}Z-\d{6}-(install|uninstall|migration)$'
        } |
        Sort-Object Name)
    if ($backups.Count -gt 5) {
        $backups | Select-Object -First ($backups.Count - 5) |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
    }
}

$AgentsRoot = [IO.Path]::GetFullPath($AgentsRoot)
$skillsRoot = Join-Path $AgentsRoot 'skills'
$target = Join-Path $skillsRoot 'dockerize'
$backupRoot = Join-Path $AgentsRoot 'skill-backups/dockerize'

Assert-ManagedDirectory -LiteralPath $AgentsRoot
Assert-ManagedDirectory -LiteralPath $skillsRoot
Assert-ManagedDirectory -LiteralPath $backupRoot

$targetItem = Get-ExistingItem -LiteralPath $target
if ($null -eq $targetItem) {
    Write-Host "Dockerize skill is not installed: $target"
    return
}
if ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Refusing to uninstall reparse-point target: $target"
}
if (-not $targetItem.PSIsContainer) {
    throw "Refusing to uninstall non-directory target: $target"
}

$null = New-Item -ItemType Directory -Path $backupRoot -Force
$backupPath = New-BackupPath -Root $backupRoot
Move-Item -LiteralPath $target -Destination $backupPath
Remove-ExpiredBackups -Root $backupRoot

Write-Host "Uninstalled Dockerize skill: $target"
Write-Host "Removed installation backed up to: $backupPath"
