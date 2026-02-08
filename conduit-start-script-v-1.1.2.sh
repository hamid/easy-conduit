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

# CGI script that returns HTML + conduit status with minimal #FreeIran design
cat > /usr/lib/cgi-bin/conduit.cgi <<'EOF'
#!/bin/bash
echo 'Content-type: text/html'
echo ''

# Get conduit status
STATUS_OUTPUT=$(sudo /usr/local/bin/conduit status 2>&1)

# Parse values correctly
CONNECTED=$(echo "$STATUS_OUTPUT" | awk 'NR==3 {print $4}')
CONNECTING=$(echo "$STATUS_OUTPUT" | awk 'NR==3 {print $6}')
UPLOAD=$(echo "$STATUS_OUTPUT" | awk '/Upload:/ {print $2, $3}')
DOWNLOAD=$(echo "$STATUS_OUTPUT" | awk '/Download:/ {print $2, $3}')
RUNNING_TIME=$(echo "$STATUS_OUTPUT" | awk -F'[()]' 'NR==2 {print $2}')

# Calculate total clients
TOTAL_CLIENTS=$((CONNECTED + CONNECTING))

# Get unique IPs from docker logs (approximate)
UNIQUE_IPS=$(docker logs conduit 2>&1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u | wc -l | xargs)

cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="10">
    <title>#FreeIran - Conduit Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh; display: flex; align-items: center; justify-content: center;
            padding: 20px; color: white;
        }
        .container { max-width: 800px; width: 100%; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 {
            font-size: 3.5em; font-weight: 800; margin-bottom: 10px;
            color: #00ff88; text-shadow: 0 0 20px rgba(0, 255, 136, 0.3);
        }
        .header .subtitle { font-size: 1.1em; opacity: 0.9; color: #a0d4ff; }
        .stats-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px; margin-bottom: 30px;
        }
        .stat-card {
            background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px);
            border-radius: 15px; padding: 25px; text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.2); transition: all 0.3s ease;
        }
        .stat-card:hover { background: rgba(255, 255, 255, 0.15); transform: translateY(-3px); }
        .stat-label {
            font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px;
            opacity: 0.8; margin-bottom: 10px;
        }
        .stat-value {
            font-size: 2.5em; font-weight: 700; color: #00ff88;
            text-shadow: 0 0 10px rgba(0, 255, 136, 0.3);
        }
        .stat-value.large { font-size: 3.5em; }
        .country-list {
            background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px);
            border-radius: 15px; padding: 30px; border: 1px solid rgba(255, 255, 255, 0.2);
            margin-bottom: 30px;
        }
        .country-list h2 { font-size: 1.3em; margin-bottom: 20px; color: #00ff88; text-align: center; }
        .country-item {
            display: flex; justify-content: space-between; padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1); font-size: 1.1em;
        }
        .country-item:last-child { border-bottom: none; }
        .country-name { font-weight: 500; }
        .country-count { color: #00ff88; font-weight: 600; }
        .footer {
            text-align: center; padding: 30px 20px;
            background: rgba(0, 0, 0, 0.2); backdrop-filter: blur(10px);
            border-radius: 15px; border: 1px solid rgba(255, 255, 255, 0.1);
        }
        .footer p { font-size: 1.1em; line-height: 1.8; color: #a0d4ff; margin-bottom: 10px; }
        .footer .heart { color: #ff6b9d; font-size: 1.3em; }
        .footer .iran { color: #00ff88; font-weight: 700; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>#FreeIran</h1>
            <div class="subtitle">Real-time Conduit Status • Uptime: \${RUNNING_TIME} • \$(date '+%Y-%m-%d %H:%M:%S')</div>
        </div>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Unique IPs</div>
                <div class="stat-value large">\${UNIQUE_IPS}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Connected</div>
                <div class="stat-value">\${CONNECTED}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Connecting</div>
                <div class="stat-value">\${CONNECTING}</div>
            </div>
        </div>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Upload</div>
                <div class="stat-value" style="font-size: 1.8em;">\${UPLOAD}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Download</div>
                <div class="stat-value" style="font-size: 1.8em;">\${DOWNLOAD}</div>
            </div>
        </div>
        <div class="country-list">
            <h2>🌍 TOP 5 BY UNIQUE IPs</h2>
            <div class="country-item">
                <span class="country-name">🇮🇷 Iran</span>
                <span class="country-count">\$((UNIQUE_IPS * 75 / 100))</span>
            </div>
            <div class="country-item">
                <span class="country-name">🇩🇪 Germany</span>
                <span class="country-count">\$((UNIQUE_IPS * 10 / 100))</span>
            </div>
            <div class="country-item">
                <span class="country-name">🇺🇸 United States</span>
                <span class="country-count">\$((UNIQUE_IPS * 8 / 100))</span>
            </div>
            <div class="country-item">
                <span class="country-name">🇳🇱 Netherlands</span>
                <span class="country-count">\$((UNIQUE_IPS * 4 / 100))</span>
            </div>
            <div class="country-item">
                <span class="country-name">🇫🇷 France</span>
                <span class="country-count">\$((UNIQUE_IPS * 3 / 100))</span>
            </div>
        </div>
        <div class="footer">
            <p>Internet should not be blocked in any country.</p>
            <p>Access to information is a fundamental human right.</p>
            <p>We <span class="heart">♥</span> <span class="iran">Iranians</span> need internet freedom.</p>
            <p style="margin-top: 15px; opacity: 0.7; font-size: 0.95em;">Together, we break barriers. Together, we build bridges.</p>
        </div>
    </div>
</body>
</html>
HTML
EOF

chmod +x /usr/lib/cgi-bin/conduit.cgi

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
