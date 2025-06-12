@echo off
setlocal enabledelayedexpansion

:: ─── REQUIREMENTS ──────────────────────────────────────────────────────────
:: • PowerShell for Get-Clipboard & math
:: • ffprobe.exe + ffmpeg.exe on your PATH
:: ────────────────────────────────────────────────────────────────────────────

echo.
echo 1. Grabbing file path from clipboard…
for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-Clipboard"') do set "input=%%~I"

if not defined input (
  echo ERROR: Clipboard didn’t contain a file path.
  pause & exit /b 1
)
if not exist "%input%" (
  echo ERROR: File "%input%" not found.
  pause & exit /b 1
)

echo   →  "%input%"
echo.

:: ─── 2. Probe total duration (seconds) ────────────────────────────────────
for /f "delims=" %%D in (
  'ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%input%"'
) do set "duration=%%D"

if not defined duration (
  echo ERROR: Could not determine duration.
  pause & exit /b 1
)

echo Duration: %duration% sec
echo.

:: ─── 3. Compute target video-bitrate ─────────────────────────────────────
:: total bits = 10MiB * 8; reserve 128 000 b/s for audio
for /f "delims=" %%B in (
  'powershell -NoProfile -Command "[math]::Floor(((10*1024*1024*8)/%duration% - 128000)/1000)"'
) do set "vbit=%%B"

if %vbit% LEQ 0 (
  echo ERROR: Computed video bitrate %vbit% kbps is too low.
  pause & exit /b 1
)

echo Target video: %vbit% kbps + audio: 128 kbps
echo.

:: ─── 4. Transcode ──────────────────────────────────────────────────────────
for %%F in ("%input%") do set "basename=%%~nF"
set "output=%basename%_under10MB.mp4"

echo Transcoding to "%output%"…
ffmpeg -y -i "%input%" ^
  -c:v libx264 -b:v %vbit%k -preset medium ^
  -c:a aac     -b:a 128k             ^
  "%output%"

echo.
echo Done! Your sub-10 MB file is "%output%".
pause