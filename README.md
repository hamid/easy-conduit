# Psiphon Conduit Deployment & Web Dashboard

Automated deployment script for Psiphon Conduit with a clean web interface to monitor real-time statistics.

## Overview

This repository contains scripts to deploy a Psiphon Conduit node with a web-based monitoring dashboard on Ubuntu/Debian servers. The dashboard displays real-time connection statistics, unique IPs, bandwidth usage, and geographic distribution of users.

## Quick Start

Run the deployment script on a fresh Ubuntu/Debian server:

```bash
wget https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-start-script-v-1.1.2.sh
chmod +x conduit-start-script-v-1.1.2.sh
sudo bash conduit-start-script-v-1.1.2.sh
```

##  Components

### 1. **conduit-start-script-v-1.1.2.sh**
Main deployment script that automates the complete setup process.

### 2. **conduit-clean.cgi**
Web interface CGI script displaying the #FreeIran dashboard with:
- Real-time client statistics
- Bandwidth monitoring
- Geographic distribution
- Clean minimal UI with custom colors

### 3. **conduit-raw.cgi**
JSON API endpoint (`/raw`) that returns structured data for programmatic access.

## 🔧 Deployment Steps

The deployment script (`conduit-start-script-v-1.1.2.sh`) performs the following steps:

### **Step 0: Initialization**
- Sets up logging to `/var/log/firstboot.log`
- Defines helper functions for retries and command checking
- Detects package manager (apt-get for Ubuntu/Debian)

### **Step 1: System Preparation**
- Updates and upgrades system packages
- Installs essential tools: `curl`, `ca-certificates`, `gnupg`, `lsb-release`, `ufw`
- Sets up non-interactive mode for unattended installation

### **Step 2: Firewall Configuration**
- Resets and configures UFW (Uncomplicated Firewall)
- Opens required ports:
  - Port 22 (SSH)
  - Port 80 (HTTP for web dashboard)
- Blocks common torrent ports (outbound):
  - 6881-6889, 6969, 51413 (TCP/UDP)
- Enables firewall with deny-by-default incoming policy

### **Step 3: Docker Installation**
- Downloads and installs Docker using official get.docker.com script
- Enables Docker service to start on boot
- Verifies Docker installation

### **Step 4: Conduit Manager Installation**
- Downloads conduit-manager script from GitHub
- Automated configuration with predefined settings:
  - **Max Clients**: 200
  - **Bandwidth Limit**: 20 Mbps per client
  - **Container Count**: Default (auto-calculated)
- Installs Psiphon Conduit in Docker container
- Verifies conduit command is available

### **Step 5: Web Dashboard Setup**
- Installs nginx web server and fcgiwrap for CGI support
- Installs apache2-utils for basic authentication
- Creates basic auth credentials (username: `iran`, password: `iran`)
- Deploys CGI scripts:
  - **Main dashboard** at `/` - Shows #FreeIran interface
  - **JSON API** at `/raw` - Returns structured data
- Configures nginx to serve the dashboard
- Enables services to start on boot

## 🌐 Accessing the Dashboard

After deployment:

### Web Interface
```
http://[YOUR_SERVER_IP]/
```
- **Username**: `iran`
- **Password**: `iran`

### JSON API
```
http://[YOUR_SERVER_IP]/raw
```
Returns JSON with:
```json
{
  "status": "running",
  "uptime": "2h24m18s",
  "clients": {
    "connected": 157,
    "connecting": 36,
    "total": 193,
    "unique_ips": 9428,
    "peak": 165
  },
  "traffic": {
    "upload": "1.10 GB",
    "download": "5.40 GB"
  },
  "top_countries": [
    {"country": "Iran", "count": 8017},
    {"country": "United States", "count": 535}
    // ... more countries
  ]
}
```

## Color Scheme

- **Background**: White (#ffffff)
- **Numbers/Values**: Dark Green (#124a3f)
- **Labels**: Red (#ab0207) to Gold (#fdba20) gradient
- **Title (#FreeIran)**: Red (#ab0207)


## Logs

All deployment logs are saved to:
```
/var/log/firstboot.log
```

View logs:
```bash
sudo tail -f /var/log/firstboot.log
```

## 🛠️ Managing Conduit

After installation, manage Conduit using:

```bash
sudo conduit          # Interactive menu
sudo conduit status   # View status
sudo conduit start    # Start Conduit
sudo conduit stop     # Stop Conduit
sudo conduit restart  # Restart Conduit
```

## 📂 File Locations

- **Conduit Manager**: `/usr/local/bin/conduit`
- **CGI Scripts**: `/usr/lib/cgi-bin/`
- **Nginx Config**: `/etc/nginx/sites-available/conduit-logs`
- **Auth File**: `/etc/nginx/auth/htpasswd`
- **Data Directory**: `/opt/conduit/traffic_stats/`

## Mission

This project supports internet freedom and helps provide censorship-resistant connectivity to users in restricted regions. The #FreeIran dashboard specifically highlights the importance of open internet access for all.

> *"Internet should not be blocked in any country. Access to information is a fundamental human right."*

## License

Open source - feel free to use and modify as needed.

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

---

**Made with ♥ for a free and open internet**
