#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build static, standalone c2enc.exe / c2dec.exe (incl. 450 bps modes) on Windows.

.DESCRIPTION
    Initializes the Codec 2 submodule, configures a static Release build with
    MinGW-w64 GCC + Ninja, builds the c2enc and c2dec tools, and copies the
    resulting standalone executables into dist/.

    CMake and Ninja are looked up on PATH first, then in common Scoop and Visual
    Studio locations, so this works even when they are not on PATH. GCC must be a
    MinGW-w64 compiler on PATH (MSVC cannot build Codec 2 - it uses C99 VLAs and
    native _Complex).
#>
[CmdletBinding()]
param(
    [string]$BuildDir = "$PSScriptRoot/build",
    [string]$DistDir  = "$PSScriptRoot/dist"
)

$ErrorActionPreference = 'Stop'

# Discover Scoop install roots (the user's may live anywhere, e.g. C:\E\kp\scoop).
function Get-ScoopRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    if ($env:SCOOP)        { $roots.Add($env:SCOOP) }
    if ($env:SCOOP_GLOBAL) { $roots.Add($env:SCOOP_GLOBAL) }
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoop) { $roots.Add((Split-Path (Split-Path $scoop.Source -Parent) -Parent)) } # ...\shims\.. = root
    $roots.Add("$env:USERPROFILE\scoop")
    $roots.Add('C:\ProgramData\scoop')
    return $roots | Where-Object { $_ } | Select-Object -Unique
}

function Resolve-Tool {
    param([string]$Name, [string[]]$Globs = @())

    $onPath = Get-Command $Name -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    # Scoop: <root>\apps\<name>\current\[bin\]<name>.exe
    foreach ($root in Get-ScoopRoots) {
        foreach ($sub in "apps\$Name\current\bin\$Name.exe", "apps\$Name\current\$Name.exe") {
            $p = Join-Path $root $sub
            if (Test-Path $p) { return (Resolve-Path $p).Path }
        }
    }

    foreach ($g in $Globs) {
        $hit = Get-ChildItem -Path $g -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

Write-Host "==> Locating toolchain" -ForegroundColor Cyan

$gcc = Resolve-Tool 'gcc' @(
    "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe",
    "C:\ProgramData\scoop\apps\gcc\current\bin\gcc.exe",
    "C:\msys64\mingw64\bin\gcc.exe"
)
if (-not $gcc) {
    throw "MinGW-w64 gcc not found on PATH. Install it (e.g. 'scoop install gcc' or MSYS2) and retry."
}

$cmake = Resolve-Tool 'cmake' @(
    "$env:USERPROFILE\scoop\apps\cmake\current\bin\cmake.exe",
    "C:\ProgramData\scoop\apps\cmake\current\bin\cmake.exe",
    "${env:ProgramFiles}\CMake\bin\cmake.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
)
if (-not $cmake) { throw "cmake not found. Install it ('scoop install cmake') and retry." }

$ninja = Resolve-Tool 'ninja' @(
    "$env:USERPROFILE\scoop\apps\ninja\current\ninja.exe",
    "C:\ProgramData\scoop\apps\ninja\current\ninja.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
)
if (-not $ninja) { throw "ninja not found. Install it ('scoop install ninja') and retry." }

$gccBin = Split-Path $gcc -Parent
$env:PATH = "$gccBin;$env:PATH"   # gcc runtime DLLs for the codebook generator at build time

Write-Host "    gcc   : $gcc"
Write-Host "    cmake : $cmake"
Write-Host "    ninja : $ninja"

Write-Host "==> Fetching Codec 2 submodule" -ForegroundColor Cyan
git -C $PSScriptRoot submodule update --init --recursive

Write-Host "==> Configuring (static Release)" -ForegroundColor Cyan
& $cmake -S "$PSScriptRoot/codec2" -B $BuildDir -G Ninja `
    -DCMAKE_MAKE_PROGRAM="$ninja" `
    -DCMAKE_C_COMPILER="$gcc" `
    -DCMAKE_BUILD_TYPE=Release `
    -DBUILD_SHARED_LIBS=OFF `
    -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc"
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed." }

Write-Host "==> Building c2enc / c2dec" -ForegroundColor Cyan
& $cmake --build $BuildDir --target c2enc c2dec
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

Write-Host "==> Collecting binaries into dist/" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
foreach ($exe in 'c2enc.exe', 'c2dec.exe') {
    Copy-Item "$BuildDir/src/$exe" $DistDir -Force
    Write-Host "    $DistDir\$exe"
}

Write-Host "==> Done." -ForegroundColor Green
& "$DistDir/c2enc.exe" 2>&1 | Select-Object -First 1
