#!/bin/sh

# Create directories
mkdir -p /usr/bin/tvgate
mkdir -p /etc/tvgate

# Load configuration using UCI directly
proxy=$(uci get tvgate.@tvgate[0].proxy 2>/dev/null)
download_url=$(uci get tvgate.@tvgate[0].download_url 2>/dev/null)

# Detect system architecture
# Binary naming convention matches tvgate Makefile
ARCH=$(uname -m)
case $ARCH in
	x86_64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-64.zip'
		BIN_NAME='TVGate-linux-64'
		;;
	i686|i386|i486|i586)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-32.zip'
		BIN_NAME='TVGate-linux-32'
		;;
	aarch64|arm64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-arm64-v8a.zip'
		BIN_NAME='TVGate-linux-arm64-v8a'
		;;
	armv7*|armv7l)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-arm32-v7a.zip'
		BIN_NAME='TVGate-linux-arm32-v7a'
		;;
	armv6*)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-arm32-v6.zip'
		BIN_NAME='TVGate-linux-arm32-v6'
		;;
	armv5*|arm*)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-arm32-v5.zip'
		BIN_NAME='TVGate-linux-arm32-v5'
		;;
	loongarch64|loong64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-loong64.zip'
		BIN_NAME='TVGate-linux-loong64'
		;;
	mips64el)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-mips64le.zip'
		BIN_NAME='TVGate-linux-mips64le'
		;;
	mips64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-mips64.zip'
		BIN_NAME='TVGate-linux-mips64'
		;;
	mipsel|mipsle)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-mips32le.zip'
		BIN_NAME='TVGate-linux-mips32le'
		;;
	mips)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-mips32.zip'
		BIN_NAME='TVGate-linux-mips32'
		;;
	ppc64le)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-ppc64le.zip'
		BIN_NAME='TVGate-linux-ppc64le'
		;;
	ppc64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-ppc64.zip'
		BIN_NAME='TVGate-linux-ppc64'
		;;
	riscv64)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-riscv64.zip'
		BIN_NAME='TVGate-linux-riscv64'
		;;
	s390x)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-s390x.zip'
		BIN_NAME='TVGate-linux-s390x'
		;;
	*)
		DEFAULT_URL='https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-64.zip'
		BIN_NAME='TVGate-linux-64'
		;;
esac

# Use configured URL or default based on architecture
if [ -z "$download_url" ] || [ "$download_url" = "none" ]; then
	download_url="$DEFAULT_URL"
	BIN_NAME_FROM_URL=""
else
	# Extract binary name from URL
	BIN_NAME_FROM_URL=$(basename "$download_url" .zip)
fi

# Determine final binary name
if [ -n "$BIN_NAME_FROM_URL" ]; then
	BIN_NAME="$BIN_NAME_FROM_URL"
fi

# Download TVGate binary with proxy support
echo "System architecture: $ARCH"
echo "Binary name: $BIN_NAME"
echo "Downloading TVGate from: $download_url"

# Handle proxy correctly
if [ -n "$proxy" ] && [ "$proxy" != "none" ]; then
	# Remove trailing slash from proxy
	proxy=$(echo "$proxy" | sed 's:/*$::')
	
	# For GitHub proxy, we need to format the URL differently
	# Proxy should be prepended to the GitHub URL: proxy/github.com/...
	# Extract the GitHub URL and format it properly for the proxy
	github_url=$(echo "$download_url" | sed 's|https://||')
	full_url="$proxy/https://$github_url"
	
	echo "Using proxy: $proxy"
else
	# No proxy specified, use direct URL
	full_url="$download_url"
fi

echo "Final download URL: $full_url"

# Try to download with curl
if command -v curl >/dev/null 2>&1; then
	curl -L --fail -o /tmp/tvgate.zip "$full_url"
	CURL_STATUS=$?
else
	echo "curl not found, cannot download."
	exit 1
fi

if [ $CURL_STATUS -eq 0 ]; then
	# Extract
	unzip -o /tmp/tvgate.zip -d /tmp

	# Move binary to final location
	mv "/tmp/$BIN_NAME" /usr/bin/tvgate/TVGate

	# Make executable
	chmod +x /usr/bin/tvgate/TVGate

	# Cleanup
	rm -f /tmp/tvgate.zip
	rm -rf /tmp/tvgate*
    rm -r /tmp/TVGate.service
	rm -r /tmp/README.md 
	echo "TVGate downloaded and installed successfully"
	exit 0
else
	echo "Failed to download TVGate"
	exit 1
fi