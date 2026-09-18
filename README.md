# Ruang Baca Kiosk (Windows Desktop)

Aplikasi kiosk mandiri **Ruang Baca Teknik Informatika** untuk Windows, dibangun
dengan Flutter. Aplikasi ini adalah **klien tipis**: seluruh logika bisnis,
data anggota, dan basis data berada di layanan API Laravel yang terpisah
(`/api/kiosk/*`). Aplikasi kiosk tidak menyimpan data apa pun selain
kredensial perangkat.

> **Arsitektur terpisah (decoupled).** Backend Laravel dan kiosk Flutter
> berjalan sebagai dua layanan berbeda. Kiosk hanya berbicara dengan server
> melalui HTTP + header API key/device token. Tidak ada akses database
> langsung dari kiosk.

---

## 1. Layanan yang tersedia

| Layanan | Menu | Alur |
| --- | --- | --- |
| Buku Tamu | `Alt+1` | Isi identitas → pilih jenis pengunjung & keperluan → kirim |
| Daftar Anggota | `Alt+2` | Isi identitas → kirim → **tunjukkan QR** ke pemindai |
| Pinjam Buku | `Alt+3` | Masukkan identitas anggota → cari & pilih buku → **scan Member Key** |
| Kembalikan Buku | `Alt+4` | Masukkan identitas anggota → pilih buku aktif → **scan Member Key** |

Semua alur meniru persis alur kiosk web (`resources/js/features/kiosk`) agar
pengalaman pengguna konsisten.

### Notifikasi hasil aksi

Setelah aksi berhasil (pinjam, kembali, kunjungan), kiosk menampilkan
**notifikasi ringan (toast)** yang **hilang sendiri** setelah 5 detik —
tidak ada tombol "Selesai" yang perlu ditekan, sehingga alur kiosk tetap
mengalir. Ini meniru `toast.success` pada kiosk web (`sonner`).

Toast tidak menangkap sentuhan, jadi kolom isian dan tombol di belakangnya
tetap dapat dipakai selama toast tampil. Galat tetap ditampilkan sebagai
`StatusBanner` di dalam form agar terbaca dan tidak lewat begitu saja.

### Pintasan keyboard

| Tombol | Fungsi |
| --- | --- |
| `Alt` + `1`–`4` | Pilih layanan (setara menekan tombol menu) |
| `Esc` | Tutup layanan yang aktif, kembali ke layar utama |

Pintasan menu **wajib** memakai `Alt` secara sengaja: kiosk ini banyak memakai
kolom isian (nomor identitas anggota, judul buku, jumlah), sehingga mengetik
angka `1`–`4` saat mengisi formulir tidak boleh berpindah menu. Keypad numerik
juga bekerja (`Alt` + `Numpad 1`–`4`).

---

## 2. Kebutuhan sistem

- **Windows 10/11** (64-bit)
- **Flutter SDK 3.13+** dengan *Desktop development with C++* (Visual Studio
  Build Tools) — hanya untuk membangun dari sumber
- Untuk menjalankan file `.exe` hasil build, cukup Visual C++ Redistributable

### ⚠️ Developer Mode (khusus build dari sumber)

Membangun plugin Windows memerlukan dukungan *symlink*. Flutter meminta
**Developer Mode** aktif:

```
start ms-settings:developers
```

Bila tidak dapat mengaktifkan Developer Mode (mis. bukan administrator), jalankan
skrip berikut **sebelum** `flutter build windows`. Skrip ini membuat *junction*
(nama alternatif Windows yang tidak butuh hak admin) sebagai pengganti symlink:

```bat
tool\mklink_plugins.bat
```

Skrip membaca daftar plugin dari `.flutter-plugins-dependencies` dan membuat
junction di `windows\flutter\ephemeral\.plugin_symlinks`. Flutter akan
melewati pembuatan tautan bila tautan sudah ada.

---

## 3. Konfigurasi

Konfigurasi dibaca berurutan (yang lebih atas menimpa yang di bawah):

1. **Variabel lingkungan** — `KIOSK_BASE_URL`, `KIOSK_API_KEY`,
   `KIOSK_DEVICE_TOKEN`, `KIOSK_DEVICE_NAME`
2. **Berkas konfigurasi** di samping `.exe`:
   - `config\kiosk.json`
   - `kiosk.json`
3. **Bawaan aplikasi** (`assets/kiosk.json`)

### Format berkas konfigurasi

```json
{
  "baseUrl": "https://ruangbaca.example.com",
  "apiKey": "rbk_xxxxxxxxxxxxxxxx",
  "deviceToken": "",
  "deviceName": "Kiosk Ruang Baca Lt.1",
  "idleTimeoutSeconds": 90,
  "kioskMode": true,
  "enableWebcamScanner": true,
  "requestTimeoutSeconds": 25
}
```

| Kunci | Arti |
| --- | --- |
| `baseUrl` | URL dasar server Laravel (tanpa `/api` di belakang) |
| `apiKey` | **API key kiosk dari server** (`php artisan kiosk:api-key`). Ini kredensial utama. |
| `deviceToken` | Opsional. Hanya untuk memantau status pendaftaran (lihat bagian 9). |
| `deviceName` | Nama perangkat, tampil di server |
| `idleTimeoutSeconds` | Detik tanpa aktivitas sebelum kembali ke layar utama |
| `kioskMode` | `true` = layar penuh + selalu di atas |
| `enableWebcamScanner` | Aktifkan pemindai QR webcam (selain scanner HID) |
| `requestTimeoutSeconds` | Batas waktu permintaan HTTP |

Salinan contoh: `config/kiosk.example.json`.

### Mendapatkan API key

Di server Laravel:

```bash
php artisan kiosk:api-key --name="Kiosk Lt.1"
```

Tempelkan nilai yang keluar ke `apiKey` pada berkas konfigurasi. API key bersifat
**permanen** — kiosk tidak memerlukan PIN maupun aktivasi perangkat.

---

## 4. Membangun & menjalankan

```bash
# 1. Ambil dependensi
flutter pub get

# 2. (Bila Developer Mode tidak aktif) buat junction plugin
tool\mklink_plugins.bat

# 3. Jalankan langsung (mode debug)
flutter run -d windows

# 4. Atau bangun rilis
flutter build windows --release
```

Hasil rilis: `build\windows\x64\runner\Release\ruangbaca_kiosk.exe`
(beserta `data\` dan DLL di folder yang sama).

---

## 5. Autentikasi

Kiosk memakai **API key bersama** (`X-Kiosk-Api-Key`) yang dikirim pada setiap
permintaan. API key bersifat permanen sampai dirotasi di server, sehingga:

- Tidak ada layar PIN atau aktivasi perangkat.
- Kiosk langsung siap dipakai setelah `apiKey` diisi pada berkas konfigurasi.
- Bila API key salah/tidak ada, kiosk menampilkan layar galat dengan tombol
  **Coba Lagi**.

Permintaan hanya diterima dari jaringan yang diizinkan server (middleware
allowlist jaringan).

---

## 6. Pemindai QR

Kiosk mendukung **dua** cara membaca Member Key:

- **Scanner HID/USB** — perangkat yang berperilaku seperti keyboard (paling
  umum di kiosk). Cukup arahkan QR ke scanner; kolom input menangkap isinya
  otomatis dan mengirim saat karakter Enter terdeteksi.
- **Webcam** — aktif bila `enableWebcamScanner: true`. Kiosk memakai
  `camera_desktop` untuk mengambil bingkai dan `flutter_zxing` (ZXing via FFI)
  untuk mendekode QR secara lokal. **Tidak ada gambar yang dikirim ke server.**

Keduanya bisa dipakai berdampingan.

---

## 7. Struktur proyek

```
lib/
├── api/            # Klien HTTP & penanganan galat
│   ├── api_exception.dart
│   └── kiosk_api.dart
├── core/           # Branding, tema, konfigurasi
├── features/
│   ├── borrow/     # Pinjam buku
│   ├── kiosk/      # Shell kiosk, menu, layar utama
│   ├── member/     # Pendaftaran anggota + klaim QR
│   ├── return/     # Kembalikan buku
│   └── visit/      # Buku tamu
├── models/         # Model data (sesuai respons API)
├── services/       # Dekoder QR (ZXing)
├── state/          # KioskController (ChangeNotifier)
└── widgets/        # Widget bersama (form, dialog, pemindai)
```

---

## 8. Pengujian

```bash
flutter analyze   # statis, harus bersih
flutter test      # uji unit logika murni
```

---

## 9. Catatan integrasi API

- Semua permintaan menyertakan `X-Kiosk-Api-Key` dan, setelah aktivasi,
  `X-Kiosk-Device-Token`. Server menerima salah satu; API key bersifat permanen
  sehingga kiosk yang sudah dikonfigurasi **tidak perlu memasukkan PIN**.
- Server mengirim sebagian field dalam `snake_case` dan sebagian `camelCase`.
  Pemetaan ditangani di `lib/models/models.dart` — **jangan** mengandalkan
  konversi otomatis.
- Peminjaman/pengembalian memakai `Idempotency-Key` (UUID v4) agar klik ganda
  tidak menghasilkan transaksi ganda.
- Lihat `docs/kiosk-api-spec.md` pada repo backend untuk detail lengkap.

### Keterbatasan: polling status pendaftaran

Endpoint `GET /api/kiosk/members/status` dan `POST /api/kiosk/members/cancel`
membaca `kiosk_device` dari **device token**, bukan API key. Bila kiosk
dioperasikan hanya dengan API key (tanpa `deviceToken`), server mengembalikan
`claim: null` sehingga status penautan Google tidak dapat dipantau dari kiosk.

Aplikasi menangani hal ini dengan aman:

- Pendaftaran tetap terkirim ke server dan QR tetap tampil.
- Hitung mundur kedaluwarsa memakai waktu lokal (bukan polling) sebagai
  sumber kebenaran.
- Bila `deviceToken` diisi, polling berjalan normal dan dialog otomatis
  menampilkan keberhasilan saat penautan selesai.

Untuk memantau status secara langsung, isi `deviceToken` pada berkas
konfigurasi dengan token perangkat dari server.

---

## 10. Versi & rilis

Versi aplikasi tercatat di `version.txt` dan **dikelola otomatis** oleh
[release-please](https://github.com/googleapis/release-please) — jangan
menyuntingnya manual.

Alur rilis:

1. Commit mengikuti [Conventional Commits](https://www.conventionalcommits.org/)
   (mis. `feat(kiosk): ...`, `fix(shortcut): ...`).
2. Setiap push ke `main`, release-please membuka/memperbarui **Release PR**
   berisi pembaruan `version.txt` dan `CHANGELOG.md`.
3. Setelah Release PR di-merge, tag `vX.Y.Z` dan GitHub Release dibuat otomatis.

### Pemeriksaan otomatis (CI)

| Workflow | Isi |
| --- | --- |
| `ci` | `dart format` check, `flutter analyze`, `flutter test` |
| `build` | `flutter build windows --release` + verifikasi artefak rilis |
| `commitlint` | Memvalidasi pesan commit (Conventional Commits) |
| `release-please` | Mengelola versi, tag, dan catatan rilis |

`main` dilindungi: perubahan masuk hanya lewat Pull Request dengan ketiga
status check (`ci`, `build`, `commitlint`) lulus.

### Menjalankan pemeriksaan secara lokal

```bash
dart format .            # rapikan format
flutter analyze          # analisis statis
flutter test             # unit & widget test
npm run commitlint       # periksa pesan commit terakhir
```
