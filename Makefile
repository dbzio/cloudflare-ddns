# Variables
BINARY_NAME=cloudflare-ddns
GO_FILES=$(wildcard *.go)
INSTALL_PATH=/usr/local/bin
SERVICE_PATH=/etc/systemd/system
CONFIG_PATH=/etc/cloudflare-ddns
LOG_PATH=/var/log/cloudflare-ddns
SERVICE_USER=cloudflare-ddns
SERVICE_GROUP=cloudflare-ddns

# Build settings
GOOS?=linux
GOARCH?=amd64
GO=go

.PHONY: all build clean install uninstall

all: build

# Build the binary
build: $(GO_FILES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build -o $(BINARY_NAME) -ldflags="-s -w" .

# Clean build artifacts
clean:
	rm -f $(BINARY_NAME)
	rm -f $(INSTALL_PATH)/$(BINARY_NAME)

# Install everything (must be run as root)
install: build install-binary install-service install-dirs

# Just install the binary
install-binary:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	install -m 755 $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)

# Install and configure the service
install-service:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	@echo "Creating service user and group..."
	@id -u $(SERVICE_USER) >/dev/null 2>&1 || useradd -r -s /bin/false $(SERVICE_USER)
	@echo "Installing systemd service..."
	@echo "[Unit]" > $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Description=Cloudflare DDNS Updater" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "After=network-online.target" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Wants=network-online.target" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "[Service]" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Type=simple" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "User=$(SERVICE_USER)" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Group=$(SERVICE_GROUP)" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "ExecStart=$(INSTALL_PATH)/$(BINARY_NAME) -env $(CONFIG_PATH)/.env" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Restart=always" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "RestartSec=60" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "StandardOutput=append:$(LOG_PATH)/ddns.log" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "StandardError=append:$(LOG_PATH)/error.log" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "# Security measures" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "ProtectSystem=strict" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "ProtectHome=true" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "NoNewPrivileges=true" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "PrivateTmp=true" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "ReadWritePaths=$(LOG_PATH)" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "[Install]" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "WantedBy=multi-user.target" >> $(SERVICE_PATH)/$(BINARY_NAME).service
	@echo "Reloading systemd..."
	systemctl daemon-reload

# Create necessary directories and set permissions
install-dirs:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	@echo "Creating directories..."
	mkdir -p $(CONFIG_PATH)
	mkdir -p $(LOG_PATH)
	@echo "Setting permissions..."
	chown $(SERVICE_USER):$(SERVICE_GROUP) $(CONFIG_PATH)
	chown $(SERVICE_USER):$(SERVICE_GROUP) $(LOG_PATH)
	chmod 755 $(CONFIG_PATH)
	chmod 755 $(LOG_PATH)
	@if [ ! -f $(CONFIG_PATH)/.env ]; then \
		echo "Creating example .env file..."; \
		echo "CLOUDFLARE_API_TOKEN=your_token_here" > $(CONFIG_PATH)/.env; \
		echo "CLOUDFLARE_ZONE_ID=your_zone_id" >> $(CONFIG_PATH)/.env; \
		echo "CLOUDFLARE_DOMAIN=your_domain" >> $(CONFIG_PATH)/.env; \
		echo "CLOUDFLARE_RECORD_ID=your_record_id" >> $(CONFIG_PATH)/.env; \
		echo "UPDATE_INTERVAL=300" >> $(CONFIG_PATH)/.env; \
		chown $(SERVICE_USER):$(SERVICE_GROUP) $(CONFIG_PATH)/.env; \
		chmod 600 $(CONFIG_PATH)/.env; \
		echo "Please edit $(CONFIG_PATH)/.env with your Cloudflare credentials."; \
	fi

# Start the service
start:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	systemctl enable $(BINARY_NAME)
	systemctl start $(BINARY_NAME)
	systemctl status $(BINARY_NAME)

# Stop the service
stop:
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	systemctl stop $(BINARY_NAME)
	systemctl disable $(BINARY_NAME)

# Uninstall everything
uninstall: stop
	@if [ "$$(id -u)" != "0" ]; then \
		echo "This target must be run as root." >&2; \
		exit 1; \
	fi
	rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	rm -f $(SERVICE_PATH)/$(BINARY_NAME).service
	rm -rf $(CONFIG_PATH)
	rm -rf $(LOG_PATH)
	systemctl daemon-reload
	@echo "Note: Service user '$(SERVICE_USER)' was not removed. Remove manually if desired."

# Show status of the service
status:
	systemctl status $(BINARY_NAME)

# Show logs
logs:
	journalctl -u $(BINARY_NAME) -f