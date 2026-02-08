#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/firstboot.log) 2>&1
echo "[+] firstboot started: $(date -Is)"

# ---------------------------
# 0) Helpers
# ---------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1; }
retry() {
  local n=0
  until "$@"; do
    n=$((n+1))
    if [ "$n" -ge 5 ]; then
      echo "[!] command failed after $n attempts: $*"
      return 1
    fi
    sleep 3
  done
}

# Detect package manager (Ubuntu/Debian)
APT=0
if need_cmd apt-get; then APT=1; fi
if [ "$APT" -ne 1 ]; then
  echo "[!] This script currently supports Debian/Ubuntu (apt-get)."
  exit 1
fi

# ---------------------------
# 1) Base packages
# ---------------------------
echo "[+] Updating packages..."
export DEBIAN_FRONTEND=noninteractive
retry apt-get update -y
retry apt-get upgrade -y

echo "[+] Installing essentials..."
retry apt-get install -y curl ca-certificates gnupg lsb-release ufw

# ---------------------------
# 2) Firewall: open ports + block common torrent ports
# ---------------------------
echo "[+] Configuring UFW firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH + HTTP
ufw allow 22/tcp
ufw allow 80/tcp

# (Optional) If later you add HTTPS, open 443:
# ufw allow 443/tcp

# "Block torrent ports" (OUTBOUND) - this is NOT a guarantee.
# Common BitTorrent/trackers defaults: 6881-6889, 6969, and often 51413 (Transmission)
ufw deny out 6881:6889/tcp || true
ufw deny out 6881:6889/udp || true
ufw deny out 6969/tcp || true
ufw deny out 6969/udp || true
ufw deny out 51413/tcp || true
ufw deny out 51413/udp || true

ufw --force enable
ufw status verbose || true

# ---------------------------
# 3) Install Docker
# ---------------------------
echo "[+] Installing Docker..."
retry curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
bash /tmp/get-docker.sh
systemctl enable --now docker
docker --version || true

# ---------------------------
# 4) Install conduit-manager (installs/controls Conduit)
# ---------------------------
echo "[+] Installing conduit-manager..."
retry curl -fsSL -o /tmp/conduit-manager.sh https://raw.githubusercontent.com/SamNet-dev/conduit-manager/main/conduit.sh
chmod +x /tmp/conduit-manager.sh

# Run conduit-manager with automatic answers to the prompts:
# 1. Enter 200 for max-clients
# 2. Answer 'n' for unlimited bandwidth (we'll set 20 Mbps)
# 3. Enter 20 for bandwidth
# 4. Press Enter for default containers
# 5. Answer 'y' to proceed with settings
echo "[+] Running conduit-manager with automatic configuration..."
{
  echo "200"       # Set max-clients to 200
  echo "n"         # Don't set unlimited bandwidth
  echo "20"        # Set bandwidth to 20 Mbps
  echo ""          # Accept recommended container count
  echo "y"         # Proceed with these settings
  echo "n"         # Don't restore backup (fresh install)
} | bash /tmp/conduit-manager.sh || true

# Wait a moment for conduit command to be available
sleep 5

# Try to ensure conduit is available
if command -v conduit >/dev/null 2>&1; then
  echo "[+] conduit command found."
  
  # Check if conduit is already running
  echo "[+] Checking conduit status..."
  conduit status || true
  
  echo "[+] Conduit installation complete!"
else
  echo "[!] conduit command not found after install script."
  echo "[!] You may need to SSH and run: sudo bash /tmp/conduit-manager.sh"
fi

# ---------------------------
# 5) Web server on port 80 with Basic Auth iran:iran showing conduit logs
# ---------------------------
echo "[+] Installing nginx + fcgiwrap for simple CGI status page..."
retry apt-get install -y nginx fcgiwrap apache2-utils

# Create htpasswd with iran:iran (INSECURE - per your request)
mkdir -p /etc/nginx/auth
htpasswd -b -c /etc/nginx/auth/htpasswd iran iran

# Create cgi-bin directory if it doesn't exist
mkdir -p /usr/lib/cgi-bin

# Download CGI scripts from GitHub
echo "[+] Downloading CGI scripts from GitHub..."
retry curl -fsSL -o /usr/lib/cgi-bin/conduit.cgi https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-clean.cgi
retry curl -fsSL -o /usr/lib/cgi-bin/conduit-raw.cgi https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-raw.cgi

chmod +x /usr/lib/cgi-bin/conduit.cgi
chmod +x /usr/lib/cgi-bin/conduit-raw.cgi

# Nginx site config for CGI + Basic Auth
cat > /etc/nginx/sites-available/conduit-logs <<'EOF'
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name _;

  auth_basic "Restricted";
  auth_basic_user_file /etc/nginx/auth/htpasswd;

  location = / {
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /usr/lib/cgi-bin/conduit.cgi;
    fastcgi_pass unix:/run/fcgiwrap.socket;
  }

  location = /conduit.cgi {
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /usr/lib/cgi-bin/conduit.cgi;
    fastcgi_pass unix:/run/fcgiwrap.socket;
  }

  location = /raw {
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /usr/lib/cgi-bin/conduit-raw.cgi;
    fastcgi_pass unix:/run/fcgiwrap.socket;
  }
}
EOF

rm -f /etc/nginx/sites-enabled/default || true
ln -sf /etc/nginx/sites-available/conduit-logs /etc/nginx/sites-enabled/conduit-logs

# Ensure fcgiwrap socket/service and nginx start on boot
systemctl enable --now fcgiwrap
nginx -t
systemctl enable --now nginx

echo "[+] Web logs available at: http://SERVER_IP/  (basic auth iran / iran)"
echo "[+] firstboot completed: $(date -Is)"
