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

    $directItem = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $directItem) {
        return $directItem
    }
    $parent = Split-Path -Parent $LiteralPath
    $leaf = Split-Path -Leaf $LiteralPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $parent -Force |
        Where-Object { $_.Name -eq $leaf } |
        Select-Object -First 1
}

function Assert-ManagedDirectory {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $item = Get-ExistingItem -LiteralPath $LiteralPath
    if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to use reparse-point directory: $LiteralPath"
    }
}

function Get-DirectoryManifest {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $root = [IO.Path]::GetFullPath($LiteralPath).TrimEnd('\', '/')
    $entries = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in (Get-ChildItem -LiteralPath $root -Force -Recurse | Sort-Object FullName)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to copy or compare reparse point: $($item.FullName)"
        }
        $relative = $item.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($item.PSIsContainer) {
            $entries.Add("D|$relative")
        } else {
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            $entries.Add("F|$relative|$($item.Length)|$hash")
        }
    }
    return $entries.ToArray()
}

function Test-DirectoriesEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $leftManifest = @(Get-DirectoryManifest -LiteralPath $Left)
    $rightManifest = @(Get-DirectoryManifest -LiteralPath $Right)
    if ($leftManifest.Count -ne $rightManifest.Count) {
        return $false
    }
    for ($index = 0; $index -lt $leftManifest.Count; $index += 1) {
        if ($leftManifest[$index] -cne $rightManifest[$index]) {
            return $false
        }
    }
    return $true
}

function New-BackupPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Kind
    )

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
        $candidate = Join-Path $Root ("{0}-{1:D6}-{2}" -f $stamp, $sequence, $Kind)
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
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceDir = Join-Path $repoRoot 'skills/dockerize'
$skillsRoot = Join-Path $AgentsRoot 'skills'
$target = Join-Path $skillsRoot 'dockerize'
$backupRoot = Join-Path $AgentsRoot 'skill-backups/dockerize'

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    throw "Source directory not found: $sourceDir"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'SKILL.md') -PathType Leaf)) {
    throw "Source SKILL.md not found: $sourceDir/SKILL.md"
}

Assert-ManagedDirectory -LiteralPath $AgentsRoot
Assert-ManagedDirectory -LiteralPath $skillsRoot
Assert-ManagedDirectory -LiteralPath $backupRoot

$targetItem = Get-ExistingItem -LiteralPath $target
if ($null -ne $targetItem -and ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Refusing to replace reparse-point target: $target"
}
if ($null -ne $targetItem -and -not $targetItem.PSIsContainer) {
    throw "Refusing to replace non-directory target: $target"
}
if ($null -ne $targetItem -and (Test-DirectoriesEqual -Left $sourceDir -Right $target)) {
    Write-Host "Dockerize skill is already up to date: $target"
    return
}

$null = New-Item -ItemType Directory -Path $AgentsRoot -Force
$null = New-Item -ItemType Directory -Path $skillsRoot -Force
$stageDir = Join-Path $AgentsRoot ('.dockerize-stage-{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [Guid]::NewGuid().ToString('N'))
$backupPath = $null

try {
    Copy-Item -LiteralPath $sourceDir -Destination $stageDir -Recurse
    if (-not (Test-Path -LiteralPath (Join-Path $stageDir 'SKILL.md') -PathType Leaf)) {
        throw 'Staged copy is missing SKILL.md'
    }
    if (-not (Test-DirectoriesEqual -Left $sourceDir -Right $stageDir)) {
        throw 'Staged copy differs from source'
    }

    if ($null -ne $targetItem) {
        $null = New-Item -ItemType Directory -Path $backupRoot -Force
        $backupPath = New-BackupPath -Root $backupRoot -Kind 'install'
        Move-Item -LiteralPath $target -Destination $backupPath
        try {
            Move-Item -LiteralPath $stageDir -Destination $target
        } catch {
            $failedTarget = Get-ExistingItem -LiteralPath $target
            if ($null -ne $failedTarget) {
                if (($failedTarget.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $failedTarget.PSIsContainer) {
                    throw "Install promotion failed and the target cannot be safely cleared; backup remains at $backupPath. $($_.Exception.Message)"
                }
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            Move-Item -LiteralPath $backupPath -Destination $target
            $backupPath = $null
            throw "Install promotion failed; previous installation was restored. $($_.Exception.Message)"
        }
        Remove-ExpiredBackups -Root $backupRoot
        Write-Host "Updated Dockerize skill: $target"
        Write-Host "Previous installation backed up to: $backupPath"
    } else {
        Move-Item -LiteralPath $stageDir -Destination $target
        Write-Host "Installed Dockerize skill: $target"
    }
} finally {
    $stageItem = Get-ExistingItem -LiteralPath $stageDir
    if ($null -ne $stageItem -and -not ($stageItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $stageDir -Recurse -Force
    }
}
