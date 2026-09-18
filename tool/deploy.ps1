# deploy.ps1 - Salin hasil build Flutter ke folder dist kiosk.
#
# Tujuan: folder dist TIDAK PERNAH tertinggal dari build terbaru, dan
# config/kiosk.json milik mesin kiosk TIDAK PERNAH tertimpa.
#
# Pemakaian:
#   powershell -ExecutionPolicy Bypass -File tool\deploy.ps1
#   powershell -ExecutionPolicy Bypass -File tool\deploy.ps1 -Dest "E:\kiosk-dist"
#
# Alur: flutter build windows --release  ->  tool\deploy.ps1  ->  jalankan exe di dist

param(
    [string]$Dest   = 'E:\ruangbaca\kiosk-dist',
    [string]$Source = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Source) {
    $Source = Join-Path $repoRoot "build\windows\x64\runner\Release"
}

Write-Host "== Deploy kiosk ==" -ForegroundColor Cyan
Write-Host "  sumber : $Source"
Write-Host "  tujuan : $Dest"

# --- 1. Validasi hasil build ------------------------------------------------
if (-not (Test-Path $Source)) {
    throw "Hasil build tidak ditemukan: $Source`nJalankan dulu: flutter build windows --release"
}

$exe = Join-Path $Source "ruangbaca_kiosk.exe"
$appSo = Join-Path $Source "data\app.so"
if (-not (Test-Path $exe))   { throw "exe tidak ada di hasil build: $exe" }
if (-not (Test-Path $appSo)) { throw "data\app.so tidak ada - build tidak lengkap" }

# Sidik jari app.so: inilah kode Dart yang sebenarnya, dan satu-satunya cara
# memastikan dist benar-benar memuat build terbaru (exe hampir tidak berubah).
$srcHash = (Get-FileHash $appSo -Algorithm MD5).Hash
Write-Host "  app.so sumber : $($srcHash.Substring(0,12))..." -ForegroundColor DarkGray

# --- 2. Hentikan kiosk yang sedang jalan -----------------------------------
$running = Get-Process -Name "ruangbaca_kiosk" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "  menghentikan kiosk yang sedang berjalan..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# --- 3. Salin isi build ke dist (config/ TIDAK disentuh) -------------------
# config/ tidak ada di folder hasil build, jadi menyalin seluruh isi Release
# tidak akan menimpa config milik mesin. Ini disengaja.
if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Write-Host "  folder tujuan dibuat" -ForegroundColor Yellow
}

Copy-Item -Path (Join-Path $Source "*") -Destination $Dest -Recurse -Force

# --- 4. Pastikan config tetap ada -----------------------------------------
$cfgDir = Join-Path $Dest "config"
$cfg    = Join-Path $cfgDir "kiosk.json"
if (-not (Test-Path $cfg)) {
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    $tpl = Join-Path $repoRoot "config\kiosk.example.json"
    if (Test-Path $tpl) {
        Copy-Item $tpl $cfg
        Write-Host "  !! config/kiosk.json belum ada - dibuat dari template." -ForegroundColor Red
        Write-Host "     ISI baseUrl + apiKey sebelum menjalankan kiosk!" -ForegroundColor Red
    } else {
        Write-Host "  !! config/kiosk.json belum ada dan template tidak ditemukan." -ForegroundColor Red
    }
}

# --- 5. Verifikasi ---------------------------------------------------------
$destAppSo = Join-Path $Dest "data\app.so"
$dstHash   = (Get-FileHash $destAppSo -Algorithm MD5).Hash
if ($srcHash -ne $dstHash) {
    throw "Verifikasi GAGAL: data\app.so di dist tidak sama dengan hasil build"
}

Write-Host "  app.so tujuan : $($dstHash.Substring(0,12))..." -ForegroundColor DarkGray
Write-Host "  config        : $(if (Test-Path $cfg) { 'ADA (tidak tertimpa)' } else { 'TIDAK ADA' })" -ForegroundColor DarkGray
Write-Host "OK - dist sudah memuat build terbaru." -ForegroundColor Green
Write-Host "Jalankan: $Dest\ruangbaca_kiosk.exe"
