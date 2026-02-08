# Easy Conduit - Automated Psiphon Conduit Deployment

One-command deployment of Psiphon Conduit with a beautiful web dashboard to monitor real-time statistics and help provide internet freedom.

## 🚀 Quick Start

Deploy on any Linux server with a single command:

```bash
wget https://raw.githubusercontent.com/hamid/easy-conduit/master/conduit-start-script-v-1.1.2.sh
chmod +x conduit-start-script-v-1.1.2.sh
sudo bash conduit-start-script-v-1.1.2.sh
```

### 🐧 Supported Operating Systems

The script automatically detects your OS and uses the appropriate package manager:

| Distribution | Versions | Package Manager | Status |
|--------------|----------|-----------------|--------|
| **Ubuntu** | 18.04+ | apt | ✅ Tested |
| **Debian** | 10+ | apt | ✅ Tested |
| **CentOS** | 7, 8, Stream | yum/dnf | ✅ Supported |
| **AlmaLinux** | 8, 9 | dnf | ✅ Supported |
| **Rocky Linux** | 8, 9 | dnf | ✅ Supported |
| **Fedora** | 35+ | dnf | ✅ Supported |

**That's it!** In ~5 minutes you'll have:
- ✅ Psiphon Conduit running in Docker
- ✅ Web dashboard at `http://YOUR_SERVER_IP/`
- ✅ JSON API at `http://YOUR_SERVER_IP/raw`
- ✅ Automatic firewall configuration
- ✅ Real-time statistics tracking

## 📊 Dashboard Features

### Main Dashboard (`/`)
Beautiful #FreeIran themed interface showing:
- **Total Connected**: Unique IPs that have connected
- **Online Clients**: Currently active connections
- **Bandwidth**: Real-time upload/download speeds
- **Geographic Distribution**: Top 5 countries by unique IPs
- **Auto-refresh**: Updates every 10 seconds

### JSON API (`/raw`)
Programmatic access to all metrics:
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
  ]
}
```

## 🔧 What Gets Installed

The deployment script automatically:

1. **System Detection**: Auto-detects OS and configures appropriate package manager
2. **System Updates**: Upgrades all packages to latest versions
3. **Docker**: Installs Docker CE for container management
4. **Firewall**: Configures firewall (UFW or firewalld) with:
   - SSH (22), HTTP (80) open
   - Torrent ports blocked
5. **Psiphon Conduit**: 
   - Max clients: 200
   - Bandwidth: 5 Mbps per client
   - Running in Docker container
6. **Web Server**: Nginx + fcgiwrap for CGI
7. **Monitoring**: Background tracker script for real-time stats

### Package Manager Support
- **Debian/Ubuntu**: Uses `apt-get` with UFW firewall
- **RHEL-based** (CentOS/AlmaLinux/Rocky/Fedora): Uses `dnf`/`yum` with firewalld
- Automatically handles package name differences across distributions

## 🌐 Access Your Dashboard

After deployment completes:

**Web Dashboard**
```
http://YOUR_SERVER_IP/
```
No authentication required - open access

**JSON API**
```
http://YOUR_SERVER_IP/raw
```
Returns structured JSON data for integration

## 🛠️ Managing Your Conduit

```bash
# Check status
sudo conduit status

# Start/Stop/Restart
sudo conduit start
sudo conduit stop  
sudo conduit restart

# View logs
sudo tail -f /var/log/firstboot.log
```

## 📂 Important Directories

- **Conduit Binary**: `/usr/local/bin/conduit`
- **Dashboard Scripts**: `/usr/lib/cgi-bin/`
- **Statistics Data**: `/opt/conduit/traffic_stats/`
- **Deployment Logs**: `/var/log/firstboot.log`

## 💝 Supporting Internet Freedom

This project is dedicated to helping provide censorship-resistant connectivity to users in restricted regions, especially Iran.

> **"Internet should not be blocked in any country. Access to information is a fundamental human right."**

Every Conduit server you deploy helps people:
- 🌍 Access blocked websites and services
- 📰 Read uncensored news and information  
- 💬 Communicate freely with the world
- 🎓 Access educational resources

## 🤝 Contributing

Want to help? You can:
- Deploy your own Conduit server
- Report bugs or suggest features
- Improve the dashboard design
- Add more language translations
- Share this project with others

## 📝 License

Open source - use freely to help spread internet freedom.

---

**Made with ♥ for a free and open internet**

*Together, we break barriers. Together, we build bridges.*

---

**Made with ♥ for a free and open internet**
