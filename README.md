# Cloudflare DDNS Updater

A lightweight Dynamic DNS (DDNS) client written in Go that automatically updates your Cloudflare DNS records when your IP address changes. This tool is particularly useful for home servers, self-hosted services, or any situation where you need to maintain accurate DNS records for a dynamic IP address.

## Features

- Automatically updates Cloudflare DNS records when your IP changes
- Runs as a systemd service
- Minimal memory footprint
- Supports IPv4 (A records)
- Configurable update interval
- Detailed logging
- Option to disable Cloudflare proxy (orange cloud)
- Secure by default with minimal permissions

## Prerequisites

- Go 1.19 or higher
- Linux system with systemd
- Cloudflare account with API token
- `make` for building and installation

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/cloudflare-ddns.git
cd cloudflare-ddns
```

2. Install the service:
```bash
sudo make install
```

3. Configure your Cloudflare credentials:
```bash
sudo nano /etc/cloudflare-ddns/.env
```

4. Start the service:
```bash
sudo make start
```

## Configuration

Create a `.env` file at `/etc/cloudflare-ddns/.env` with the following variables:

```env
CLOUDFLARE_API_TOKEN=your_token_here
CLOUDFLARE_ZONE_ID=your_zone_id
CLOUDFLARE_DOMAIN=your_domain
CLOUDFLARE_RECORD_ID=your_record_id
UPDATE_INTERVAL=300  # Update interval in seconds (default: 300)
```

### Getting Cloudflare Credentials

1. **API Token**: 
   - Go to Cloudflare Dashboard > My Profile > API Tokens
   - Create a token with `Zone.DNS` edit permissions for your zone

2. **Zone ID**:
   - Go to your domain's overview page
   - Find Zone ID in the right sidebar

3. **Record ID**:
   - Go to DNS Management
   - Click on the target DNS record
   - The Record ID will be in the URL or record details

## Usage

### Service Management

Start the service:
```bash
sudo make start
```

Check status:
```bash
make status
```

View logs:
```bash
make logs
```

Stop the service:
```bash
sudo make stop
```

### Manual Build

Build the binary:
```bash
make build
```

Clean build artifacts:
```bash
make clean
```

### Uninstall

Remove the service and all associated files:
```bash
sudo make uninstall
```

## Directory Structure

```
/usr/local/bin/cloudflare-ddns     # Binary
/etc/cloudflare-ddns/.env          # Configuration
/var/log/cloudflare-ddns/          # Log files
/etc/systemd/system/cloudflare-ddns.service  # Systemd service
```

## Logging

- Service logs: `/var/log/cloudflare-ddns/ddns.log`
- Error logs: `/var/log/cloudflare-ddns/error.log`
- System journal: `journalctl -u cloudflare-ddns`

## Security

The service runs with minimal privileges:
- Dedicated non-privileged user
- Protected system directories
- No new privileges allowed
- Private /tmp directory
- Limited write access (logs only)
- Protected home directories

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make build` | Build the binary |
| `make install` | Install service and binary |
| `make start` | Start the service |
| `make stop` | Stop the service |
| `make status` | Check service status |
| `make logs` | View service logs |
| `make uninstall` | Remove service and files |
| `make clean` | Remove build artifacts |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgments

- [Cloudflare API](https://api.cloudflare.com/)
- [ipify API](https://api.ipify.org/) for IP address detection