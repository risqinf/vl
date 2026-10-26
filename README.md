# Autoscript VL

Autoscript VL adalah tunneling stack modern yang dirancang khusus untuk protokol **VLESS WebSocket (WS Non-TLS & WS TLS)** pada Ubuntu 24.04 LTS dan Debian 13.

Menggunakan 100% binary statis tanpa proses kompilasi pada VPS target, sehingga proses instalasi sangat cepat, ringan, dan stabil.

---

## Fitur Utama

- **VLESS WebSocket Only**:
  - VLESS WebSocket HTTP (Port: 80, 8880, 2082) - Path: `/vless-ws`
  - VLESS WebSocket TLS / HTTPS (Port: 443, 8443, 2053, 2083) - Path: `/vless-ws`
  - Mendukung CDN Cloudflare & Direct SNI
- **Monitoring Bandwidth Real-Time (vnStat)**:
  - Informasi bandwidth usage langsung di header dashboard menu
  - Trafik hari ini (Today)
  - Trafik kemarin (Yesterday)
  - Total trafik bulan ini (Monthly)
  - Perintah cepat `vnstat` atau `bandwidth` untuk laporan detail harian/bulanan
- **Multi-Login IP Limiter**:
  - Deteksi real client IP via HAProxy PROXY Protocol v2
  - Auto-lock akun yang melanggar limit login
  - Fitur Auto-Unlock otomatis setelah 5 menit cooldown
- **Manajemen Kuota & Masa Aktif**:
  - Batasan kuota bandwidth data (GB)
  - Pembersihan otomatis akun yang sudah expired (daily systemd timer)
- **Operasional Seller VPN**:
  - Tambah akun, akun trial 1 hari, perpanjang, pemulihan akun (recovery)
  - Cetak slip konfigurasi akun
  - Ban / Unban akun manual
  - Reset kuota pemakaian
- **Sistem & Keamanan**:
  - Manajemen domain & penerbitan sertifikat SSL otomatis (Let's Encrypt / Fallback)
  - Notifikasi bot Telegram otomatis
  - Backup & restore konfigurasi database via Telegram

---

## Persyaratan Sistem

- **OS**: Ubuntu 24.04 LTS / Debian 13
- **Akses**: Root (`sudo su`)
- **Port**: Bebas dari Apache2 / Nginx bawaan (installer akan mengamankan port 80 & 443)
- **Domain**: Domain / subdomain yang sudah diarahkan (pointing) ke IP server

---

## Instalasi Cepat

Jalankan perintah berikut di terminal VPS Anda sebagai root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/risqinf/vl/main/install.sh)
```

Atau tentukan domain langsung melalui argumen:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/risqinf/vl/main/install.sh) --domain vpn.domainanda.com
```

---

## Penggunaan Menu Interaktif

Setelah instalasi selesai, cukup ketik:

```bash
menu
```

Atau gunakan perintah:

```bash
vl
```

---

## Perintah CLI Cepat

| Perintah | Deskripsi |
|---|---|
| `menu` | Membuka Dashboard Interaktif TUI |
| `bandwidth` / `vnstat` | Melihat rincian penggunaan bandwidth server |
| `add-vless` | Membuat akun VLESS baru |
| `trial-vless` | Membuat akun trial VLESS 1 hari |
| `del-vless` | Menghapus akun VLESS |
| `renew-vless` | Memperpanjang masa aktif akun VLESS |
| `list-vless` | Menampilkan seluruh daftar akun VLESS |
| `slip-vless` | Mencetak link konfigurasi VLESS |
| `cek-vless` | Memantau koneksi aktif & multi-login real-time |
| `ban` | Mengunci akun pengguna |
| `unban` | Membuka kunci akun pengguna |
| `reset-quota` | Mereset kuota penggunaan akun ke 0 |
| `recovery` | Memulihkan akun expired dengan masa aktif baru |
| `ceklim` | Memeriksa pelanggaran batas IP |
| `xp` | Membersihkan akun expired secara manual |
| `domain` | Mengganti domain server |
| `renew-cert` | Memperbarui sertifikat SSL |
| `restart` | Memulai ulang seluruh layanan Autoscript VL |

---

## Lisensi & Distribusi

Repositori ini hanya berisi binary statis dan script konfigurasi siap pakai (tanpa source code).
Dikelola oleh [risqinf](https://github.com/risqinf).
