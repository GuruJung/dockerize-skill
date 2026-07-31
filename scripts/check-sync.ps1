[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$koreanFile = Join-Path $repoRoot 'locales/ko/dockerize/SKILL.md'
$englishFile = Join-Path $repoRoot 'skills/dockerize/SKILL.md'
$manifest = Join-Path $repoRoot 'sync/dockerize.sha256'

foreach ($requiredFile in @($koreanFile, $englishFile, $manifest)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required sync file not found: $requiredFile"
    }
    $item = Get-Item -LiteralPath $requiredFile -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing reparse-point sync file: $requiredFile"
    }
}

$values = @{}
foreach ($line in (Get-Content -LiteralPath $manifest)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $parts = $line.Split([char[]]'=', 2)
    if ($parts.Count -ne 2 -or $values.ContainsKey($parts[0])) {
        throw "Malformed sync manifest line: $line"
    }
    if ($parts[0] -notin @('version', 'korean_sha256', 'english_sha256')) {
        throw "Unknown sync manifest key: $($parts[0])"
    }
    $values[$parts[0]] = $parts[1]
}

if ($values['version'] -ne '1') {
    throw 'Sync manifest version must be 1'
}
foreach ($key in @('korean_sha256', 'english_sha256')) {
    if ($values[$key] -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Invalid $key in sync manifest"
    }
}

$actualKorean = (Get-FileHash -LiteralPath $koreanFile -Algorithm SHA256).Hash.ToLowerInvariant()
$actualEnglish = (Get-FileHash -LiteralPath $englishFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($values['korean_sha256'].ToLowerInvariant() -ne $actualKorean) {
    throw 'Korean source changed after the last semantic sync review; translate and record sync again'
}
if ($values['english_sha256'].ToLowerInvariant() -ne $actualEnglish) {
    throw 'English skill changed after the last semantic sync review; update both versions and record sync again'
}

Write-Host 'Korean source and English skill are in sync.'
