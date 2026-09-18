@echo off
setlocal
REM ---------------------------------------------------------------------------
REM Fallback bila Developer Mode Windows tidak dapat diaktifkan.
REM
REM Flutter butuh symlink untuk windows/flutter/ephemeral/.plugin_symlinks.
REM Membuat symlink butuh hak admin (atau Developer Mode). Skrip ini membuat
REM *junction* sebagai gantinya - junction tidak butuh hak admin.
REM
REM Jalankan HANYA bila `flutter build windows` gagal dengan galat symlink.
REM Daftar plugin dibaca dari .flutter-plugins-dependencies, dan folder sumber
REM dicari di pub cache, sehingga skrip ini tidak bergantung pada path tertentu
REM (versi sebelumnya mengunci path D:\ruangbaca-kiosk sehingga gagal di mesin
REM lain).
REM ---------------------------------------------------------------------------

set "ROOT=%~dp0.."

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root = (Resolve-Path (Join-Path '%~dp0..' '.')).Path;" ^
  "$sl   = Join-Path $root 'windows\flutter\ephemeral\.plugin_symlinks';" ^
  "$dep  = Join-Path $root '.flutter-plugins-dependencies';" ^
  "if (-not (Test-Path $dep)) { Write-Host 'LEWAT: .flutter-plugins-dependencies belum ada. Jalankan dulu: flutter pub get'; exit 1 }" ^
  "if (-not (Test-Path $sl)) { New-Item -ItemType Directory -Path $sl -Force | Out-Null }" ^
  "$cache = Join-Path $env:LOCALAPPDATA 'Pub\Cache\hosted\pub.dev';" ^
  "$json  = Get-Content $dep -Raw | ConvertFrom-Json;" ^
  "$plugins = $json.plugins.windows;" ^
  "if (-not $plugins) { Write-Host 'Tidak ada plugin Windows.'; exit 0 }" ^
  "foreach ($p in $plugins) {" ^
  "  $name   = $p.name;" ^
  "  $target = Join-Path $sl $name;" ^
  "  if (Test-Path $target) { Write-Host ('  ada    : ' + $name); continue }" ^
  "  $src = Get-ChildItem $cache -Directory -Filter ($name + '-*') -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1;" ^
  "  if (-not $src) { Write-Host ('  LEWAT  : ' + $name + ' (tidak ada di pub cache)'); continue }" ^
  "  cmd /c mklink /J \"$target\" \"$($src.FullName)\" | Out-Null;" ^
  "  Write-Host ('  dibuat : ' + $name + ' -> ' + $src.Name);" ^
  "}"

echo DONE
