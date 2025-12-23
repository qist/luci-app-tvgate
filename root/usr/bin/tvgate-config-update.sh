#!/bin/sh

# Load configuration using UCI directly
listen_port=$(uci get tvgate.@tvgate[0].listen_port 2>/dev/null)

# Set default if not found
[ -z "$listen_port" ] && listen_port="8888"

# Path to the config file
CONFIG_PATH=/etc/tvgate/config.yaml

# Check if config file exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "Config file does not exist at $CONFIG_PATH, TVGate should generate it automatically"
    exit 1
fi

# Update the port value in the config file
if grep -q "^port:" "$CONFIG_PATH"; then
    # Update existing port value
    sed -i "s/^port:.*/port: $listen_port/" "$CONFIG_PATH"
else
    # Add port value to the beginning of the file
    sed -i "1i\port: $listen_port\n" "$CONFIG_PATH"
fi

echo "TVGate config updated with port: $listen_port"