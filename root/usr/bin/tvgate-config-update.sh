#!/bin/sh

# Load configuration using UCI directly
# listen_port=$(uci get tvgate.@tvgate[0].listen_port 2>/dev/null)
listen_port="$1"
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
# 只更新 server: 下的 port 字段（2空格缩进）
sed -i '/^server:/,/^[^ ]/s/^  port:.*/  port: '"$listen_port"'/' "$CONFIG_PATH"

echo "TVGate config updated with server port: $listen_port"

echo "TVGate config updated with port: $listen_port"