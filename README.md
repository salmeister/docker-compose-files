
# Homelab Docker Compose Collection

A comprehensive collection of Docker Compose configurations for running a complete homelab setup on Ubuntu. This repository contains battle-tested configurations for media servers, home automation, monitoring, security, and productivity applications.

## 🏠 Overview

This homelab setup uses Docker containers orchestrated through Docker Compose to provide a complete self-hosted infrastructure. All services are integrated with SWAG (Secure Web Application Gateway) for reverse proxy and SSL termination, making them accessible via custom subdomains.

## 🚀 Quick Start

### Prerequisites
- Ubuntu Server (24.04)
- Docker and Docker Compose
- Domain name with DNS pointing to your server
- Basic understanding of Docker networking

## 📁 Services by Category

### 🎵 Media & Entertainment
- **[Plex](./plex/)** - Media server with GPU acceleration for transcoding
  - Features: NVIDIA GPU support, multiple media libraries, network discovery
  
- **[Immich](./immich/)** - Self-hosted photo and video management
  - Features: AI-powered photo organization, machine learning with CUDA support
  
- **[Transmission](./transmission/)** - BitTorrent client with VPN
  - Features: OpenVPN integration, secure downloading

### 🏡 Home Automation
- **[Home Assistant](./homeassistant/)** - Complete home automation platform
  - Includes: Zigbee2MQTT, Z-Wave JS, ESPHome, Frigate NVR, Code Server
  - Features: Device integration, automation, dashboards

- **[Frigate](./homeassistant/)** - NVR with object detection
  - Features: AI object detection, GPU acceleration, Coral TPU support, RTSP streaming

### 🔧 Productivity & Organization
- **[Nextcloud](./nextcloud/)** - File sync and collaboration platform
  - Features: File sharing, calendar, contacts, Redis caching
  
- **[Mealie](./mealie/)** - Recipe management and meal planning
  - Features: Recipe import, meal planning, shopping lists
  
- **[Obsidian LiveSync](./obsidian/)** - Note-taking with real-time sync
  - Features: CouchDB backend for Obsidian sync

### 🔒 Security & Privacy
- **[Vaultwarden](./vaultwarden/)** - Bitwarden-compatible password manager
  - Features: Self-hosted password management, SMTP notifications
  
- **[Wireguard](./wireguard/)** - VPN server
  - Features: Fast, secure VPN access to homelab

### 🖥️ Infrastructure & Management
- **[SWAG](./swag/)** - Reverse proxy with automatic SSL
  - Features: Let's Encrypt SSL, Cloudflare DNS, auto-proxy discovery
  
- **[Portainer](./portainer/)** - Docker container management
  - Features: Web-based Docker management interface
  
- **[Watchtower](./watchtower/)** - Automatic container updates
  - Features: Monitors and updates Docker images

### 📊 Monitoring & Observability
- **[Prometheus](./prometheus/)** - Metrics collection and alerting
  - Features: Time-series database, node monitoring
  
- **[Grafana](./prometheus/)** - Data visualization and dashboards
  - Features: Beautiful dashboards, alerting
  
- **[Healthchecks](./healthchecks/)** - Service monitoring and notifications
  - Features: Cron job monitoring, email alerts

### 🤖 AI & Machine Learning
- **[Ollama](./ollama/)** - Local LLM hosting
  - Features: GPU acceleration, traffic control, multiple models
  
- **[Open WebUI](./ollama/)** - Web interface for Ollama
  - Features: ChatGPT-like interface for local LLMs

### 🌐 Networking
- **[Omada Controller](./omada/)** - TP-Link network management
  - Features: Centralized network configuration
  
- **[OpenSearch](./opensearch/)** - Search and analytics engine
  - Features: Log aggregation and search

### 🗂️ Custom Applications
- **[PhotoSorter](./photosorter/)** - Custom photo organization tool
  - Features: Automatic photo sorting by date
  
- **[MyBudget](./salmeister/)** - Personal budgeting application
  - Features: Custom financial tracking

### 📦 Development & Registry
- **[Docker Registry](./registry/)** - Private Docker image registry
  - Features: Store custom Docker images locally

## 🔧 Network Architecture

All services use a shared Docker network (`shared-net`) for inter-service communication. SWAG acts as the central reverse proxy, providing:
- Automatic SSL certificate management via Let's Encrypt
- Subdomain routing (e.g., `plex.yourdomain.com`, `ha.yourdomain.com`)
- Rate limiting and security headers
- Cloudflare DNS integration

## 📋 Environment Variables

Most services require environment variables stored in `.env` files. Common variables include:
- `DOMAIN_NAME` - Your domain name
- `SWAG_ADDRESS` - SWAG container address
- Database credentials
- API keys and tokens
- Email configuration for notifications

## 🛠️ Hardware Requirements

### Minimum Specs
- 4GB RAM (8GB+ recommended)
- 2 CPU cores (4+ recommended)
- 100GB storage (SSD recommended)
- Ubuntu 22.04+ or similar Docker-compatible OS

### Recommended Hardware
- **GPU**: NVIDIA GPU for Plex transcoding, Frigate object detection, and Ollama
- **Coral TPU**: For enhanced Frigate object detection
- **USB Devices**: Zigbee coordinator, Z-Wave stick for Home Assistant
- **Storage**: NAS or large external storage for media libraries

### My Current Setup (Example Configuration)

This homelab runs on a custom-built system optimized for 24/7 operation, media transcoding, and AI workloads:

#### **Core Components**
- **CPU**: AMD Ryzen 7 3700X (8-core, 3.6GHz) - Excellent performance/power ratio for containerized workloads
- **Motherboard**: ASRock X470D4U2-2T - Server-grade board with dual 10G LAN and IPMI for remote management
- **RAM**: 16GB Kingston Server Premier DDR4-2666 ECC - Error-correcting memory for stability
- **GPU**: ASUS Dual RTX 3060 V2 OC (12GB GDDR6) - Powers Plex transcoding, Frigate AI, and Ollama LLMs

#### **Storage Configuration**
- **OS Drive**: WD Red SA500 1TB M.2 SSD - Fast, reliable storage for containers and databases
- **Media Storage**: WD Red 6TB NAS HDD (5400 RPM) - High-capacity storage for Plex media library
- **Additional**: 8x 3.5" drive bays available for expansion

#### **Infrastructure**
- **PSU**: EVGA 750W 80+ Gold Semi-Modular - Efficient power delivery with room for expansion
- **Case**: Antec P101 Silent - Optimized for quiet operation with excellent drive capacity
- **Networking**: Dual 10GbE ports for high-bandwidth applications and network redundancy
- **Management**: IPMI support for remote server administration

#### **Performance Benefits**
- **ECC Memory**: Prevents data corruption in long-running containers
- **10G Networking**: Enables fast file transfers and low-latency service communication
- **GPU Acceleration**: Supports multiple simultaneous Plex transcodes and AI inference
- **Silent Operation**: Designed for home environment with minimal noise

### Operating System & Storage

#### **OS Configuration**
- **Distribution**: Ubuntu Server 24.04 LTS - Latest long-term support release with modern kernel
- **File System**: ZFS - Advanced file system with built-in data integrity and snapshot capabilities
- **RAID Configuration**: ZFS Mirror (RAID-1) - Provides redundancy and data protection
- **Container Runtime**: Docker with Docker Compose - Industry-standard containerization

#### **ZFS Benefits for Homelab**
- **Data Integrity**: Built-in checksumming prevents silent data corruption
- **Snapshots**: Point-in-time recovery for configuration backups
- **Compression**: Automatic data compression saves storage space
- **Scrubbing**: Regular data verification ensures long-term reliability
- **Easy Expansion**: Simple pool expansion when adding drives

#### **Storage Layout**
- **System Pool**: ZFS mirror for OS and container data
- **Media Storage**: Dedicated drives for large media files
- **Backup Strategy**: ZFS snapshots combined with external backup solutions

## ️ Archived Services

The `_archive/` directory contains configurations for services that are no longer active but kept for reference:
- AdGuard, Grafana (standalone), Jellyfin, Registry, and others

## 📖 Getting Started with Individual Services

Each service directory contains:
- `docker-compose.yml` - Main configuration
- `.env.example` - Environment variable template (if applicable)
- `README.md` - Service-specific documentation (where available)

### Example: Starting Plex
```bash
cd plex/
# Copy and configure environment variables
cp .env.example .env
nano .env

# Start the service
docker-compose up -d

# View logs
docker-compose logs -f
```

## 🔄 Maintenance

### Updates
Most services use Watchtower for automatic updates, but you can manually update:
```bash
cd <service-directory>
docker-compose pull
docker-compose up -d
```

### Backups
Important data directories to backup:
- Configuration directories for each service
- Database volumes
- Media libraries (if stored locally)

### Monitoring
- Grafana dashboards provide system metrics
- Healthchecks monitors service availability
- SWAG logs provide access and security information

## ⚠️ Security Notes

- Change default passwords in all `.env` files
- Regularly update containers for security patches
- Use strong passwords and enable 2FA where available
- Consider firewall rules for exposed ports
- Review SWAG security configurations

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LinuxServer.io Images](https://docs.linuxserver.io/)
- [Self-Hosted Software List](https://github.com/awesome-selfhosted/awesome-selfhosted)

---

**Note**: This setup is designed for personal homelab use. Adapt security settings and configurations as needed for your specific environment and security requirements.
