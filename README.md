# C2EncWindows

Standalone Windows builds of **Codec 2**'s `c2enc` / `c2dec` command-line tools —
including the ultra‑low‑bitrate **450 bps** and **450PWB** modes that upstream
Codec 2 removed one commit before its v1.2.0 release.

[![build](https://github.com/muhammetozeski/C2EncWindows/actions/workflows/build.yml/badge.svg)](https://github.com/muhammetozeski/C2EncWindows/actions/workflows/build.yml)

---

## What is this?

[Codec 2](https://github.com/drowe67/codec2) is an open‑source speech codec that
compresses voice down to bitrates between 3200 and 450 bits per second — far below
anything MP3/AAC reach. It is used for digital voice over HF/VHF radio (FreeDV).

Two things make this repo useful on Windows:

1. **The 450 bps modes are back.** Upstream removed `CODEC2_MODE_450` and
   `CODEC2_MODE_450PWB` in commit [`6549fa1`](https://github.com/drowe67/codec2/commit/6549fa1)
   ("rm-ed 450 & 450WB"), the day before v1.2.0 was tagged. This repo pins Codec 2
   to the commit right before that (`9f5e2de`), so `c2enc` / `c2dec` can still
   encode at **450 bps** — the lowest bitrate Codec 2 ever shipped.
2. **It builds with MinGW and runs standalone.** The produced `c2enc.exe` /
   `c2dec.exe` depend only on `KERNEL32.dll` and `msvcrt.dll` (always present on
   Windows). No DLLs to copy, no MSYS2 runtime, no Visual C++ redistributable.

> Codec 2's C sources use C99 variable‑length arrays and native `_Complex`
> arithmetic, neither of which MSVC's C compiler supports — so the supported
> Windows toolchain is **MinGW‑w64 (GCC)**, which is what this repo uses.

## Bitrate modes

| Mode      | Bitrate   | Notes                                  |
|-----------|-----------|----------------------------------------|
| `3200`    | 3200 bps  | highest quality                        |
| `2400`    | 2400 bps  |                                        |
| `1600`    | 1600 bps  |                                        |
| `1400`    | 1400 bps  |                                        |
| `1300`    | 1300 bps  |                                        |
| `1200`    | 1200 bps  |                                        |
| `700C`    | 700 bps   | lowest mode in current upstream/ffmpeg |
| `450`     | 450 bps   | **lowest bitrate** (restored here)     |
| `450PWB`  | 450 bps   | 450 with pseudo‑wideband decode        |

## Download

Grab `c2enc.exe` and `c2dec.exe` from the
[**Releases**](https://github.com/muhammetozeski/C2EncWindows/releases) page.
They are self‑contained — drop them anywhere and run.

## Usage

`c2enc` / `c2dec` work on **headerless 8 kHz, 16‑bit, mono, little‑endian raw PCM**.

```text
c2enc <mode> <input.raw> <output.c2>
c2dec <mode> <input.c2>  <output.raw>
```

Encode at the lowest bitrate, then decode back:

```powershell
c2enc 450 speech8k.raw speech.c2
c2dec 450 speech.c2    decoded8k.raw
```

## Converting real audio (MP3, AMR, WAV, ...)

Codec 2 only eats raw 8 kHz mono PCM, so use [FFmpeg](https://ffmpeg.org) to get
in and out of normal audio files:

```powershell
# any audio  ->  raw PCM Codec 2 understands
ffmpeg -i input.mp3 -ar 8000 -ac 1 -f s16le speech8k.raw

# encode to 450 bps
c2enc 450 speech8k.raw speech.c2

# decode back to raw, then to a playable WAV
c2dec 450 speech.c2 decoded8k.raw
ffmpeg -f s16le -ar 8000 -ac 1 -i decoded8k.raw decoded.wav
```

`convert.ps1` wraps this pipeline so you can point it straight at audio files or a
folder:

```powershell
# encode one file or a whole folder to .c2 at 450 bps
./convert.ps1 -Path "C:\audio" -Mode 450 -OutDir "C:\audio\codec2"
```

## Build from source

**Prerequisites** (all on `PATH`):

- MinGW‑w64 GCC — `scoop install gcc`  (or MSYS2 `mingw-w64-x86_64-gcc`)
- CMake        — `scoop install cmake`
- Ninja        — `scoop install ninja`

```powershell
git clone --recursive https://github.com/muhammetozeski/C2EncWindows.git
cd C2EncWindows
./build.ps1
```

`build.ps1` initializes the Codec 2 submodule, configures a static Release build
(`BUILD_SHARED_LIBS=OFF`, `-static`) and drops `c2enc.exe` / `c2dec.exe` into
`dist/`. It auto‑detects CMake/Ninja from `PATH`, Scoop, or a Visual Studio
install if they aren't on `PATH`.

## Credits & license

- **Codec 2** © David Rowe and contributors — [LGPL‑2.1](https://github.com/drowe67/codec2)
  (pulled in as a submodule, built unmodified).
- This repository's scripts, CI and docs are MIT‑licensed — see [LICENSE](LICENSE).
