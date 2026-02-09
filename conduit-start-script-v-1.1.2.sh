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

# Wait for package manager lock to be released (Debian/Ubuntu)
wait_for_apt_lock() {
  echo "[+] Waiting for package manager lock to be released..."
  local max_wait=300  # 5 minutes max wait
  local waited=0
  
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    
    if [ $waited -ge $max_wait ]; then
      echo "[!] Timeout waiting for apt lock. Killing blocking processes..."
      killall -9 apt apt-get unattended-upgrade 2>/dev/null || true
      sleep 5
      break
    fi
    
    echo "[*] Package manager is locked (likely unattended-upgrades). Waiting... (${waited}s/${max_wait}s)"
    sleep 10
    waited=$((waited + 10))
  done
  
  echo "[+] Package manager is now available"
}

# Detect OS and package manager
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
    OS_NAME="${NAME}"
    OS_VERSION="${VERSION_ID}"
    echo "[+] Detected OS: ${NAME} ${VERSION_ID}"
  else
    echo "[!] Cannot detect OS. /etc/os-release not found."
    exit 1
  fi
  
  # Determine package manager and commands
  if need_cmd apt-get; then
    PKG_MANAGER="apt"
    PKG_UPDATE="apt-get update -y"
    PKG_UPGRADE="apt-get upgrade -y"
    PKG_INSTALL="apt-get install -y"
    FIREWALL_CMD="ufw"
    NGINX_USER="www-data"
    export DEBIAN_FRONTEND=noninteractive
    echo "[+] Using apt package manager"
  elif need_cmd dnf; then
    PKG_MANAGER="dnf"
    PKG_UPDATE="dnf check-update || true"
    PKG_UPGRADE="dnf upgrade -y"
    PKG_INSTALL="dnf install -y"
    FIREWALL_CMD="firewalld"
    NGINX_USER="nginx"
    echo "[+] Using dnf package manager"
  elif need_cmd yum; then
    PKG_MANAGER="yum"
    PKG_UPDATE="yum check-update || true"
    PKG_UPGRADE="yum upgrade -y"
    PKG_INSTALL="yum install -y"
    FIREWALL_CMD="firewalld"
    NGINX_USER="nginx"
    echo "[+] Using yum package manager"
  else
    echo "[!] No supported package manager found (apt-get, dnf, or yum)."
    exit 1
  fi
}

detect_os

# ---------------------------
# 1) Base packages
# ---------------------------
echo "[+] Updating packages..."

# Wait for any existing package operations to complete (Debian/Ubuntu only)
if [ "$PKG_MANAGER" = "apt" ]; then
  wait_for_apt_lock
fi

retry $PKG_UPDATE
retry $PKG_UPGRADE

echo "[+] Installing essentials..."
if [ "$PKG_MANAGER" = "apt" ]; then
  retry $PKG_INSTALL curl ca-certificates gnupg lsb-release ufw
else
  # RHEL-based systems
  retry $PKG_INSTALL curl ca-certificates gnupg2
fi

# ---------------------------
# 2) Firewall: configure only on Ubuntu/Debian
# ---------------------------
# 2) Firewall: configure only on Ubuntu/Debian
# ---------------------------
# Note: On RHEL-based systems (CentOS, AlmaLinux, Rocky, Fedora), 
# we skip full firewall configuration to avoid DBus conflicts during cloud-init,
# but we still enable HTTP service
if [ "$FIREWALL_CMD" = "ufw" ]; then
  echo "[+] Configuring firewall (Ubuntu/Debian)..."
  
  # UFW (Ubuntu/Debian)
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  # Allow SSH + HTTP
  ufw allow 22/tcp
  ufw allow 80/tcp

  # Block torrent ports (OUTBOUND)
  ufw deny out 6881:6889/tcp || true
  ufw deny out 6881:6889/udp || true
  ufw deny out 6969/tcp || true
  ufw deny out 6969/udp || true
  ufw deny out 51413/tcp || true
  ufw deny out 51413/udp || true

  ufw --force enable
  ufw status verbose || true
else
  echo "[+] Skipping firewall configuration on RHEL-based systems"
  echo "[!] Note: After installation, manually run: firewall-cmd --permanent --add-service=http && firewall-cmd --reload"
fi

# ---------------------------
# 3) Install Docker
# ---------------------------
echo "[+] Installing Docker..."

# Check if AlmaLinux (get.docker.com doesn't support it yet)
if [[ "$OS_NAME" == *"AlmaLinux"* ]]; then
  echo "[+] Installing Docker manually for AlmaLinux..."
  
  # Add Docker CE repository
  retry $PKG_INSTALL yum-utils device-mapper-persistent-data lvm2
  retry yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  
  # Install Docker (--allowerasing removes conflicting podman packages)
  retry dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-compose-plugin
  
  # Disable SELinux (prevents nginx fcgiwrap socket connection issues)
  if command -v getenforce >/dev/null 2>&1; then
    echo "[+] Disabling SELinux for nginx/fcgiwrap compatibility..."
    setenforce 0 2>/dev/null || true
    sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 2>/dev/null || true
  fi
  
  systemctl enable --now docker
  docker --version || true
else
  # Use official Docker install script for other distros
  retry curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  bash /tmp/get-docker.sh
  systemctl enable --now docker
  docker --version || true
fi

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
# 5) Web server on port 80 showing conduit status
# ---------------------------
echo "[+] Installing nginx + fcgiwrap for simple CGI status page..."

if [ "$PKG_MANAGER" = "apt" ]; then
  retry $PKG_INSTALL nginx fcgiwrap
else
  # RHEL-based: need EPEL for fcgiwrap
  if [ "$PKG_MANAGER" = "dnf" ]; then
    retry $PKG_INSTALL epel-release
  elif [ "$PKG_MANAGER" = "yum" ]; then
    retry $PKG_INSTALL epel-release
  fi
  # Install nginx and fcgiwrap (spawn-fcgi not available on newer CentOS)
  retry $PKG_INSTALL nginx fcgiwrap
fi

# Create cgi-bin directory if it doesn't exist
mkdir -p /usr/lib/cgi-bin

# Download CGI scripts from GitHub
echo "[+] Downloading CGI scripts from GitHub..."
retry curl -fsSL -o /usr/lib/cgi-bin/conduit.cgi https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-clean.cgi
retry curl -fsSL -o /usr/lib/cgi-bin/conduit-raw.cgi https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-raw.cgi

chmod +x /usr/lib/cgi-bin/conduit.cgi
chmod +x /usr/lib/cgi-bin/conduit-raw.cgi

# Allow nginx user to run conduit command without password (for CGI scripts)
echo "${NGINX_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/conduit" | tee /etc/sudoers.d/${NGINX_USER}-conduit
chmod 0440 /etc/sudoers.d/${NGINX_USER}-conduit

# Nginx site config for CGI
if [ "$PKG_MANAGER" = "apt" ]; then
  # Debian/Ubuntu: uses sites-available/sites-enabled
  cat > /etc/nginx/sites-available/conduit-logs <<'EOF'
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name _;

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

  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/conduit-logs /etc/nginx/sites-enabled/conduit-logs
  
else
  # RHEL-based: uses conf.d
  cat > /etc/nginx/conf.d/conduit-logs.conf <<'EOF'
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name _;

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

  # Remove default server block
  sed -i 's/listen.*80 default_server;//g' /etc/nginx/nginx.conf 2>/dev/null || true
  
  # RHEL-based: Check if fcgiwrap has built-in systemd units
  if [ "$FIREWALL_CMD" != "ufw" ]; then
    # Check if template-based units exist (CentOS Stream 10+)
    if [ -f /usr/lib/systemd/system/fcgiwrap@.socket ]; then
      echo "[+] Detected fcgiwrap template units (CentOS Stream 10+)..."
      # Update nginx config to use the template socket path
      sed -i 's|unix:/run/fcgiwrap.socket|unix:/run/fcgiwrap/fcgiwrap-nginx.sock|g' /etc/nginx/conf.d/conduit-logs.conf
    else
      echo "[+] Creating fcgiwrap systemd units for RHEL-based system..."
      
      cat > /etc/systemd/system/fcgiwrap.socket << 'FCGI_SOCKET_EOF'
[Unit]
Description=fcgiwrap Socket

[Socket]
ListenStream=/run/fcgiwrap.socket

[Install]
WantedBy=sockets.target
FCGI_SOCKET_EOF

      cat > /etc/systemd/system/fcgiwrap.service << 'FCGI_SERVICE_EOF'
[Unit]
Description=Simple CGI Server
After=nss-user-lookup.target
Requires=fcgiwrap.socket

[Service]
ExecStart=/usr/sbin/fcgiwrap -c 4
User=nginx
Group=nginx
Restart=on-failure

[Install]
Also=fcgiwrap.socket
FCGI_SERVICE_EOF

      systemctl daemon-reload
    fi
  fi
fi

# Ensure fcgiwrap socket/service and nginx start on boot
if [ "$FIREWALL_CMD" != "ufw" ]; then
  # RHEL: Check if template units exist (CentOS Stream 10+)
  if [ -f /usr/lib/systemd/system/fcgiwrap@.socket ]; then
    echo "[+] Enabling fcgiwrap template socket for nginx user..."
    systemctl stop fcgiwrap@nginx.service 2>/dev/null || true
    systemctl stop fcgiwrap@nginx.socket 2>/dev/null || true
    systemctl enable fcgiwrap@nginx.socket
    systemctl start fcgiwrap@nginx.socket
  else
    echo "[+] Enabling fcgiwrap socket..."
    systemctl enable --now fcgiwrap.socket
    systemctl start fcgiwrap.service || true
  fi
else
  # Ubuntu/Debian: fcgiwrap has built-in systemd units
  systemctl enable --now fcgiwrap
fi
nginx -t
systemctl enable --now nginx
systemctl restart nginx

# Post-installation: Configure firewalld on RHEL systems (after cloud-init)
if [ "$FIREWALL_CMD" != "ufw" ]; then
  echo "[+] Configuring firewalld (post-installation)..."
  (sleep 5 && firewall-cmd --permanent --add-service=http 2>/dev/null && firewall-cmd --reload 2>/dev/null && echo "[+] Firewall HTTP enabled") &
fi

echo "[+] Web dashboard available at: http://SERVER_IP/"
echo "[+] firstboot completed: $(date -Is)"
