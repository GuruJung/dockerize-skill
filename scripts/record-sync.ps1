[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$koreanFile = Join-Path $repoRoot 'locales/ko/dockerize/SKILL.md'
$englishFile = Join-Path $repoRoot 'skills/dockerize/SKILL.md'
$syncDir = Join-Path $repoRoot 'sync'
$manifest = Join-Path $syncDir 'dockerize.sha256'

foreach ($requiredFile in @($koreanFile, $englishFile)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required skill file not found: $requiredFile"
    }
}

if (Test-Path -LiteralPath $syncDir) {
    $syncItem = Get-Item -LiteralPath $syncDir -Force
    if (($syncItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $syncItem.PSIsContainer) {
        throw "Refusing unsafe sync directory: $syncDir"
    }
} else {
    $null = New-Item -ItemType Directory -Path $syncDir
}
$manifestExists = Test-Path -LiteralPath $manifest
if ($manifestExists) {
    $manifestItem = Get-Item -LiteralPath $manifest -Force
    if (($manifestItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $manifestItem.PSIsContainer) {
        throw "Refusing unsafe sync manifest: $manifest"
    }
}

$koreanHash = (Get-FileHash -LiteralPath $koreanFile -Algorithm SHA256).Hash.ToLowerInvariant()
$englishHash = (Get-FileHash -LiteralPath $englishFile -Algorithm SHA256).Hash.ToLowerInvariant()
$content = "version=1`nkorean_sha256=$koreanHash`nenglish_sha256=$englishHash`n"
$tempManifest = Join-Path $syncDir ('.dockerize.sha256.tmp.{0}' -f [Guid]::NewGuid().ToString('N'))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    [IO.File]::WriteAllText($tempManifest, $content, $utf8NoBom)
    if ($manifestExists) {
        [IO.File]::Replace($tempManifest, $manifest, $null)
    } else {
        [IO.File]::Move($tempManifest, $manifest)
    }
} finally {
    if (Test-Path -LiteralPath $tempManifest -PathType Leaf) {
        Remove-Item -LiteralPath $tempManifest -Force
    }
}

Write-Host 'Recorded Dockerize skill sync hashes after semantic review.'
