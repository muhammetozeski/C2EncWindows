#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Encode audio files to Codec 2 (.c2) using FFmpeg + c2enc.

.DESCRIPTION
    Codec 2 only accepts raw 8 kHz / 16-bit / mono PCM. This wrapper uses FFmpeg
    to convert any input audio (mp3, amr, wav, m4a, ...) to that format and pipes
    it through c2enc at the requested mode. Point -Path at a single file or a
    folder (all audio files in it are converted).

.EXAMPLE
    ./convert.ps1 -Path "C:\audio" -Mode 450 -OutDir "C:\audio\codec2"

.EXAMPLE
    ./convert.ps1 -Path lecture.mp3 -Mode 700C
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Path,
    [ValidateSet('3200','2400','1600','1400','1300','1200','700C','450','450PWB')]
    [string]$Mode = '450',
    [string]$OutDir,
    [string]$C2Enc,
    [string[]]$Extensions = @('.mp3','.amr','.wav','.m4a','.aac','.ogg','.opus','.flac','.wma','.mp4')
)

$ErrorActionPreference = 'Stop'

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue)?.Source
if (-not $ffmpeg) { throw "ffmpeg not found on PATH. Install it (e.g. 'scoop install ffmpeg')." }

if (-not $C2Enc) {
    $C2Enc = Resolve-Path -ErrorAction SilentlyContinue "$PSScriptRoot/dist/c2enc.exe"
    if (-not $C2Enc) { $C2Enc = (Get-Command c2enc -ErrorAction SilentlyContinue)?.Source }
}
if (-not $C2Enc -or -not (Test-Path -LiteralPath $C2Enc)) {
    throw "c2enc.exe not found. Build it first (./build.ps1) or pass -C2Enc <path>."
}

# Collect inputs
$item = Get-Item -LiteralPath $Path
if ($item.PSIsContainer) {
    $files = Get-ChildItem -LiteralPath $Path -File | Where-Object { $Extensions -contains $_.Extension.ToLower() }
    if (-not $OutDir) { $OutDir = Join-Path $Path 'codec2' }
} else {
    $files = @($item)
    if (-not $OutDir) { $OutDir = $item.DirectoryName }
}

if (-not $files) { Write-Warning "No matching audio files found in '$Path'."; return }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("c2_" + [System.IO.Path]::GetRandomFileName() + ".raw")
$ok = 0; $fail = 0; $i = 0

foreach ($f in $files) {
    $i++
    $dest = Join-Path $OutDir ($f.BaseName + ".c2")
    Write-Host ("[{0}/{1}] {2}  ->  {3} ({4})" -f $i, $files.Count, $f.Name, (Split-Path $dest -Leaf), $Mode)
    & $ffmpeg -hide_banner -loglevel error -y -i $f.FullName -ar 8000 -ac 1 -f s16le $tmp
    if ($LASTEXITCODE -eq 0) {
        & $C2Enc $Mode $tmp $dest
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dest)) { $ok++ } else { $fail++; Write-Warning "c2enc failed: $($f.Name)" }
    } else { $fail++; Write-Warning "ffmpeg failed: $($f.Name)" }
}

Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
Write-Host ("Done. OK={0} FAIL={1}  ->  {2}" -f $ok, $fail, $OutDir) -ForegroundColor Green
