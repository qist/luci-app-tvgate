#!/bin/sh

# 接收端口参数
listen_port="$1"
[ -z "$listen_port" ] && listen_port="8888"

CONFIG_PATH=/etc/tvgate/config.yaml

# 检查文件是否存在
if [ ! -f "$CONFIG_PATH" ]; then
    echo "Config file does not exist at $CONFIG_PATH, TVGate should generate it automatically"
    exit 1
fi

# 删除 server 块里已有的 port 行（忽略缩进和空格/tab）
sed -i '/^server:/,/^[^[:space:]]/ {
    /^[[:space:]]*port:/d
}' "$CONFIG_PATH"

# 在 server: 后面插入新的 port 行，保持 4 空格缩进
sed -i '/^server:/a\
    port: '"$listen_port"'
' "$CONFIG_PATH"

echo "TVGate config updated with server port: $listen_port"
