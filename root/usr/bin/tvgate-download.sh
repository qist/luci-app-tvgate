#!/bin/sh

# Load configuration
config_load tvgate
local proxy download_url

config_get proxy proxy 'https://hk.gh-proxy.com/'
config_get download_url download_url ''

# Detect system architecture
ARCH=$(uname -m)
case $ARCH in
	x86_64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-amd64.zip'
		BIN_NAME='TVGate-linux-amd64'
		;;
	aarch64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-arm64.zip'
		BIN_NAME='TVGate-linux-arm64'
		;;
	armv7l)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-armv7.zip'
		BIN_NAME='TVGate-linux-armv7'
		;;
	mips)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-mips.zip'
		BIN_NAME='TVGate-linux-mips'
		;;
	mipsle)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-mipsle.zip'
		BIN_NAME='TVGate-linux-mipsle'
		;;
	*)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-amd64.zip'
		BIN_NAME='TVGate-linux-amd64'
		;;
esac

# Use configured URL or default based on architecture
if [ -z "$download_url" ] || [ "$download_url" = "none" ]; then
	download_url="$DEFAULT_URL"
else
	# Extract binary name from URL
	BIN_NAME=$(basename "$download_url" .zip)
fi

# Create directories
mkdir -p /usr/bin/tvgate
mkdir -p /etc/tvgate

# Download TVGate binary with proxy support
echo "System architecture: $ARCH"
echo "Binary name: $BIN_NAME"
echo "Downloading TVGate from: $download_url"

if [ -n "$proxy" ] && [ "$proxy" != "none" ]; then
	full_url="${proxy}/${download_url}"
	echo "Using proxy: $proxy"
else
	full_url="$download_url"
fi

# Try to download
wget -O /tmp/tvgate.zip "$full_url"

if [ $? -eq 0 ]; then
	# Extract
	unzip -o /tmp/tvgate.zip -d /tmp
	
	# Move binary to final location
	mv "/tmp/$BIN_NAME" /usr/bin/tvgate/TVGate
	
	# Make executable
	chmod +x /usr/bin/tvgate/TVGate
	
	# Cleanup
	rm -f /tmp/tvgate.zip
	rm -rf /tmp/tvgate*
	
	echo "TVGate downloaded and installed successfully"
	exit 0
else
	echo "Failed to download TVGate"
	exit 1
fi