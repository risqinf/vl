#!/usr/bin/env bash
# ==============================================================================
# Autoscript VL - Automated VLESS WebSocket Stack Installer
# Engineered for Ubuntu 24.04 LTS & Debian 13 (Systemd, Glibc)
# 100% Static Binaries - Zero Compilation on Target VPS
# Protocols: VLESS WebSocket (HTTP & TLS / Cloudflare CDN)
# ==============================================================================

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

DEFAULT_REPO="risqinf/vl"
DEFAULT_BRANCH="main"

print_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${BOLD}${PURPLE}          AUTOSCRIPT VL - AUTO INSTALLER (VLESS WS)         ${NC}"
    echo -e " ${BOLD}${CYAN}          Optimized for Ubuntu 24.04 LTS & Debian 13        ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_ok()   { echo -e " ${GREEN}[OK]${NC} $1"; }
print_info() { echo -e " ${CYAN}[INFO]${NC} $1"; }
print_warn() { echo -e " ${YELLOW}[WARN]${NC} $1"; }
print_err()  { echo -e " ${RED}[ERR]${NC} $1"; }

# 1. Root Check
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    print_err "Script ini harus dijalankan sebagai root!"
    exit 1
fi

# 2. OS Compatibility Check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VER="$VERSION_ID"
else
    print_err "File /etc/os-release tidak ditemukan. Hanya Ubuntu dan Debian yang didukung."
    exit 1
fi

if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
    print_warn "Distribusi '$OS_ID' terdeteksi. Script dioptimalkan untuk Ubuntu 24.04 dan Debian 13."
fi

# 3. Detect Source Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJECT_DIR=""

is_valid_dir() {
    local d="$1"
    [ -n "$d" ] && [ -d "$d" ] && [ -f "$d/conf/haproxy.cfg" ] && [ -f "$d/install.sh" ]
}

if is_valid_dir "$SCRIPT_DIR"; then
    PROJECT_DIR="$SCRIPT_DIR"
elif is_valid_dir "$(pwd)"; then
    PROJECT_DIR="$(pwd)"
elif is_valid_dir "/root/vl"; then
    PROJECT_DIR="/root/vl"
elif is_valid_dir "$HOME/vl"; then
    PROJECT_DIR="$HOME/vl"
fi

# Parse CLI Flags
PARAM_DOMAIN=""
FORCE_LOCAL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            FORCE_LOCAL=1
            shift
            ;;
        --domain)
            PARAM_DOMAIN="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

print_header

# If local source not found, download package from GitHub
if [ -z "$PROJECT_DIR" ] && [ "$FORCE_LOCAL" -eq 0 ]; then
    print_info "Mengunduh paket instalasi Autoscript VL dari https://github.com/${DEFAULT_REPO}..."
    mkdir -p /root/vl
    local_archive="/tmp/vl.tar.gz"
    rm -f "$local_archive"
    download_ok=0

    if curl -fsSL -o "$local_archive" "https://github.com/${DEFAULT_REPO}/archive/refs/heads/${DEFAULT_BRANCH}.tar.gz" 2>/dev/null; then
        download_ok=1
    elif wget -qO "$local_archive" "https://github.com/${DEFAULT_REPO}/archive/refs/heads/${DEFAULT_BRANCH}.tar.gz" 2>/dev/null; then
        download_ok=1
    fi

    if [ "$download_ok" -eq 1 ] && [ -s "$local_archive" ]; then
        tar -xzf "$local_archive" -C /root/vl --strip-components=1 2>/dev/null || true
        rm -f "$local_archive"
        if is_valid_dir "/root/vl"; then
            PROJECT_DIR="/root/vl"
        fi
    fi

    # Fallback to git clone if tarball failed or files incomplete
    if ! is_valid_dir "$PROJECT_DIR"; then
        print_warn "Download arsip tar.gz tidak lengkap, mencoba fallback git clone..."
        if ! command -v git >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y >/dev/null 2>&1 || true
            apt-get install -y git >/dev/null 2>&1 || true
        fi
        rm -rf /root/vl
        if git clone --depth 1 "https://github.com/${DEFAULT_REPO}.git" /root/vl 2>/dev/null; then
            if is_valid_dir "/root/vl"; then
                PROJECT_DIR="/root/vl"
            fi
        fi
    fi
fi

if ! is_valid_dir "$PROJECT_DIR"; then
    print_err "Direktori project Autoscript VL tidak valid atau file konfigurasi tidak lengkap!"
    print_err "Pastikan repositori https://github.com/${DEFAULT_REPO} dapat diakses."
    exit 1
fi

print_ok "Direktori project terdeteksi: $PROJECT_DIR"

# 4. Input Domain
DOMAIN="$PARAM_DOMAIN"
if [ -z "$DOMAIN" ]; then
    if [ -f /etc/vl/domain ]; then
        EXISTING_DOMAIN=$(head -n 1 /etc/vl/domain | tr -d ' \r\n')
    elif [ -f /etc/shvl/domain ]; then
        EXISTING_DOMAIN=$(head -n 1 /etc/shvl/domain | tr -d ' \r\n')
    fi
    echo ""
    echo -e "${BOLD}${YELLOW}Masukkan domain/subdomain yang telah di-pointing ke IP server ini:${NC}"

    if [ -t 0 ]; then
        if [ -n "$EXISTING_DOMAIN" ]; then
            read -r -p "Domain [$EXISTING_DOMAIN]: " INPUT_DOMAIN
            DOMAIN="${INPUT_DOMAIN:-$EXISTING_DOMAIN}"
        else
            read -r -p "Domain : " DOMAIN
        fi
    elif [ -e /dev/tty ]; then
        if [ -n "$EXISTING_DOMAIN" ]; then
            read -r -p "Domain [$EXISTING_DOMAIN]: " INPUT_DOMAIN </dev/tty 2>/dev/null || true
            DOMAIN="${INPUT_DOMAIN:-$EXISTING_DOMAIN}"
        else
            read -r -p "Domain : " DOMAIN </dev/tty 2>/dev/null || true
        fi
    fi
fi

DOMAIN=$(echo "$DOMAIN" | tr -d ' \r\n')

if [ -z "$DOMAIN" ]; then
    DOMAIN=$(curl -s --connect-timeout 2 ifconfig.me 2>/dev/null || curl -s --connect-timeout 2 icanhazip.com 2>/dev/null || echo "127.0.0.1")
    print_warn "Domain tidak diisi, menggunakan IP server: $DOMAIN"
fi

print_ok "Domain yang digunakan: $DOMAIN"

# 5. Runtime Dependencies (Includes vnstat)
print_info "Memperbarui paket sistem & menginstal dependensi runtime..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y haproxy curl wget jq socat cron net-tools iptables zip unzip python3 psmisc vnstat >/dev/null 2>&1 || {
    print_warn "Percobaan pertama apt gagal, mencoba sekali lagi..."
    apt-get install -y haproxy curl wget jq socat cron net-tools iptables zip unzip python3 psmisc vnstat || true
}

# Stop conflicting default services if running
systemctl stop apache2 nginx haproxy 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true

# 6. Create System Directories & Compatibility Links
mkdir -p /etc/vl /etc/vl/ssl /etc/xray /var/log/xray /etc/haproxy /var/lib/vnstat /usr/local/bin /usr/local/sbin /usr/sbin /usr/bin
if [ ! -d /etc/shvl ] && [ ! -L /etc/shvl ]; then
    ln -sf /etc/vl /etc/shvl
fi

# 7. Deploy Static Binaries (No Build Time!)
print_info "Memasang binary statis (Xray Core, VL Core, vnStat)..."

BIN_SRC="$PROJECT_DIR/bin"
[ -d "$PROJECT_DIR/bin/amd64" ] && BIN_SRC="$PROJECT_DIR/bin/amd64"

if [ -f "$BIN_SRC/vl-core" ]; then
    cp -f "$BIN_SRC/vl-core" /usr/local/bin/vl-core
elif [ -f "$PROJECT_DIR/bin/vl-core" ]; then
    cp -f "$PROJECT_DIR/bin/vl-core" /usr/local/bin/vl-core
elif [ -f "$BIN_SRC/shvl" ]; then
    cp -f "$BIN_SRC/shvl" /usr/local/bin/vl-core
fi

cp -f /usr/local/bin/vl-core /usr/local/bin/shvl 2>/dev/null || true

if [ -f "$BIN_SRC/xray" ]; then
    cp -f "$BIN_SRC/xray" /usr/local/bin/xray
elif [ -f "$PROJECT_DIR/bin/xray" ]; then
    cp -f "$PROJECT_DIR/bin/xray" /usr/local/bin/xray
fi

if [ -f "$BIN_SRC/geoip.dat" ]; then
    cp -f "$BIN_SRC/geoip.dat" /usr/local/bin/geoip.dat
    cp -f "$BIN_SRC/geoip.dat" /etc/xray/geoip.dat
fi
if [ -f "$BIN_SRC/geosite.dat" ]; then
    cp -f "$BIN_SRC/geosite.dat" /usr/local/bin/geosite.dat
    cp -f "$BIN_SRC/geosite.dat" /etc/xray/geosite.dat
fi

# Deploy vnstat binaries as fallback / direct
if [ -f "$BIN_SRC/vnstat" ]; then
    cp -f "$BIN_SRC/vnstat" /usr/local/bin/vnstat
    [ ! -f /usr/bin/vnstat ] && cp -f "$BIN_SRC/vnstat" /usr/bin/vnstat 2>/dev/null || true
fi
if [ -f "$BIN_SRC/vnstatd" ]; then
    cp -f "$BIN_SRC/vnstatd" /usr/local/sbin/vnstatd
    [ ! -f /usr/sbin/vnstatd ] && cp -f "$BIN_SRC/vnstatd" /usr/sbin/vnstatd 2>/dev/null || true
fi

# Deploy master CLI
cp -f "$PROJECT_DIR/scripts/vl" /usr/local/bin/vl
chmod +x /usr/local/bin/vl /usr/local/bin/vl-core /usr/local/bin/shvl /usr/local/bin/xray /usr/local/bin/vnstat /usr/local/sbin/vnstatd 2>/dev/null || true
ln -sf /usr/local/bin/vl /usr/bin/vl 2>/dev/null || true

# Verify binaries
if [ ! -x /usr/local/bin/vl-core ] || [ ! -x /usr/local/bin/xray ]; then
    print_err "Gagal menyalin binary statis! Pastikan folder bin/ tersedia."
    exit 1
fi
print_ok "Binary statis terverifikasi:"
print_ok "  * Xray Core: $(/usr/local/bin/xray version 2>&1 | head -n 1)"
print_ok "  * VL Core  : $(/usr/local/bin/vl-core version 2>&1 | head -n 1)"
print_ok "  * vnStat   : $(/usr/local/bin/vnstat --version 2>&1 | head -n 1)"

# 8. Deploy Configurations
print_info "Memasang konfigurasi sistem..."
echo "$DOMAIN" > /etc/vl/domain
echo "$DOMAIN" > /etc/shvl/domain 2>/dev/null || true
echo "$DOMAIN" > /etc/xray/domain

[ -f "$PROJECT_DIR/conf/haproxy.cfg" ] && cp -f "$PROJECT_DIR/conf/haproxy.cfg" /etc/haproxy/haproxy.cfg
[ -f "$PROJECT_DIR/conf/xray.json" ] && cp -f "$PROJECT_DIR/conf/xray.json" /etc/xray/config.json
[ -f "$PROJECT_DIR/conf/vl.conf" ] && cp -f "$PROJECT_DIR/conf/vl.conf" /etc/vl/vl.conf
[ -f "$PROJECT_DIR/conf/issue.net" ] && cp -f "$PROJECT_DIR/conf/issue.net" /etc/vl/issue.net

ln -sf /etc/vl/vl.conf /etc/shvl/shvl.conf 2>/dev/null || true
ln -sf /etc/vl/issue.net /etc/shvl/issue.net 2>/dev/null || true

if [ -f /etc/vl/vl.conf ]; then
    sed -i "s|^DOMAIN=.*|DOMAIN=\"$DOMAIN\"|" /etc/vl/vl.conf 2>/dev/null || true
fi

# Deploy scripts
cp -f "$PROJECT_DIR/scripts/"* /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/* 2>/dev/null || true

# 9. SSL Certificate Provisioning
print_info "Menerbitkan sertifikat SSL untuk domain $DOMAIN..."
/usr/local/bin/renew-cert || true

# If certificate bundle is still missing, generate self-signed fallback immediately
if [ ! -f /etc/vl/vl.pem ]; then
    mkdir -p /etc/vl/ssl
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
        -subj "/CN=$DOMAIN" -keyout /etc/vl/ssl/privkey.pem -out /etc/vl/ssl/fullchain.pem >/dev/null 2>&1
    cat /etc/vl/ssl/fullchain.pem /etc/vl/ssl/privkey.pem > /etc/vl/vl.pem
    chmod 600 /etc/vl/vl.pem
fi

ln -sf /etc/vl/vl.pem /etc/shvl/shvl.pem 2>/dev/null || true

# 10. Deploy Systemd Service Units & vnStat
print_info "Memasang unit service systemd..."
cp -f "$PROJECT_DIR/systemd/xray.service" /etc/systemd/system/xray.service
cp -f "$PROJECT_DIR/systemd/vl-limiter.service" /etc/systemd/system/vl-limiter.service
cp -f "$PROJECT_DIR/systemd/vl-xp.service" /etc/systemd/system/vl-xp.service
cp -f "$PROJECT_DIR/systemd/vl-xp.timer" /etc/systemd/system/vl-xp.timer

ln -sf /etc/systemd/system/vl-limiter.service /etc/systemd/system/shvl-limiter.service 2>/dev/null || true
ln -sf /etc/systemd/system/vl-xp.service /etc/systemd/system/shvl-xp.service 2>/dev/null || true
ln -sf /etc/systemd/system/vl-xp.timer /etc/systemd/system/shvl-xp.timer 2>/dev/null || true

# Initialize vnStat monitoring daemon
mkdir -p /var/lib/vnstat
NET_IFACE=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n 1)
[ -z "$NET_IFACE" ] && NET_IFACE="eth0"
vnstat -u -i "$NET_IFACE" 2>/dev/null || true
systemctl enable vnstat >/dev/null 2>&1 || true
systemctl restart vnstat >/dev/null 2>&1 || true

systemctl daemon-reload
for svc in xray haproxy vl-limiter vnstat; do
    systemctl enable "$svc.service" >/dev/null 2>&1 || true
    systemctl restart "$svc.service" >/dev/null 2>&1 || true
done
systemctl enable --now vl-xp.timer >/dev/null 2>&1 || true

# 11. Deploy Interactive Menus & CLI Commands
print_info "Memasang menu TUI & command alias..."
cp -f "$PROJECT_DIR/menu/menu" /usr/local/bin/menu
cp -f "$PROJECT_DIR/menu/menu-vless" /usr/local/bin/menu-vless

ln -sf /usr/local/bin/menu /usr/bin/menu 2>/dev/null || true
ln -sf /usr/local/bin/menu-vless /usr/bin/menu-vless 2>/dev/null || true
ln -sf /usr/local/bin/renew-cert /usr/local/bin/cert 2>/dev/null || true
ln -sf /usr/local/bin/renew-cert /usr/bin/renew-cert 2>/dev/null || true
ln -sf /usr/local/bin/renew-cert /usr/bin/cert 2>/dev/null || true

# Link scripts to /usr/bin
for sc in add-vless trial-vless del-vless renew-vless list-vless slip-vless cek-vless ban unban recovery reset-quota autokill ceklim xp restart bandwidth vnstat; do
    [ -f "/usr/local/bin/$sc" ] && ln -sf "/usr/local/bin/$sc" "/usr/bin/$sc" 2>/dev/null || true
done

# Add menu alias to profile files
for rc in /root/.bashrc /root/.profile /etc/bash.bashrc /etc/profile; do
    if [ -f "$rc" ] && ! grep -q "alias menu=" "$rc" 2>/dev/null; then
        echo "alias menu='/usr/local/bin/menu'" >> "$rc" 2>/dev/null || true
    fi
    if [ -f "$rc" ] && ! grep -q "alias vl=" "$rc" 2>/dev/null; then
        echo "alias vl='/usr/local/bin/vl'" >> "$rc" 2>/dev/null || true
    fi
done

# Initialize Database
/usr/local/bin/vl xp >/dev/null 2>&1 || true

# 12. Installation Summary
IP=$(curl -s --connect-timeout 2 ifconfig.me 2>/dev/null || echo "127.0.0.1")
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${BOLD}${GREEN}          INSTALASI AUTOSCRIPT VL BERHASIL SELESAI              ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WHITE}Domain Server${NC}     : ${GREEN}$DOMAIN${NC}"
echo -e "  ${WHITE}IP Address${NC}        : ${GREEN}$IP${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}${YELLOW}DAFTAR PROTOKOL & PORT:${NC}"
echo -e "  * ${WHITE}VLESS WebSocket (HTTP)${NC} : 80, 8880, 2082 [Path: /vless-ws]"
echo -e "  * ${WHITE}VLESS WebSocket (TLS)${NC}  : 443, 8443, 2053, 2083 [Path: /vless-ws]"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}${YELLOW}FITUR SISTEM:${NC}"
echo -e "  * Monitoring Bandwidth (vnstat - Hari Ini, Kemarin, Total Bulan Ini)"
echo -e "  * Multi-login IP Limiter Daemon (5 Menit Cooldown Auto-Unlock)"
echo -e "  * Notifikasi Bot Telegram otomatis"
echo -e "  * Daily Auto-Expiry cleaner (Systemd timer)"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "  Ketik ${BOLD}${GREEN}menu${NC} untuk membuka Dashboard Interaktif."
echo -e "  Ketik ${BOLD}${GREEN}vl help${NC} untuk melihat perintah CLI."
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
