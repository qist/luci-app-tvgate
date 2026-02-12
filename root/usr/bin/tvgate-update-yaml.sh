#!/bin/sh

# 读取参数
while [ $# -gt 0 ]; do
    case "$1" in
        --web-path)
            WEB_PATH="$2"
            shift 2
            ;;
        --monitor-path)
            MONITOR_PATH="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --log-enabled)
            LOG_ENABLED="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --log-maxsize)
            LOG_MAXSIZE="$2"
            shift 2
            ;;
        --log-maxbackups)
            LOG_MAXBACKUPS="$2"
            shift 2
            ;;
        --log-maxage)
            LOG_MAXAGE="$2"
            shift 2
            ;;
        --log-compress)
            LOG_COMPRESS="$2"
            shift 2
            ;;
        --multicast-ifaces)
            MULTICAST_IFACES="$2"
            HAS_MULTICAST_IFACES=1
            shift 2
            ;;
        --mcast-rejoin-interval)
            MCAST_REJOIN_INTERVAL="$2"
            HAS_MCAST_REJOIN_INTERVAL=1
            shift 2
            ;;
        --fcc-type)
            FCC_TYPE="$2"
            HAS_FCC_TYPE=1
            shift 2
            ;;
        --fcc-cache-size)
            FCC_CACHE_SIZE="$2"
            HAS_FCC_CACHE_SIZE=1
            shift 2
            ;;
        --fcc-listen-port-min)
            FCC_LISTEN_PORT_MIN="$2"
            HAS_FCC_LISTEN_PORT_MIN=1
            shift 2
            ;;
        --fcc-listen-port-max)
            FCC_LISTEN_PORT_MAX="$2"
            HAS_FCC_LISTEN_PORT_MAX=1
            shift 2
            ;;
        --upstream-interface)
            UPSTREAM_INTERFACE="$2"
            HAS_UPSTREAM_INTERFACE=1
            shift 2
            ;;
        --upstream-interface-fcc)
            UPSTREAM_INTERFACE_FCC="$2"
            HAS_UPSTREAM_INTERFACE_FCC=1
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 清理路径值，移除首尾空格
clean_path() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# 清理所有路径值
if [ -n "$WEB_PATH" ]; then
    WEB_PATH=$(clean_path "$WEB_PATH")
fi
if [ -n "$MONITOR_PATH" ]; then
    MONITOR_PATH=$(clean_path "$MONITOR_PATH")
fi
if [ -n "$LOG_FILE" ]; then
    LOG_FILE=$(clean_path "$LOG_FILE")
fi
if [ -n "$PORT" ]; then
    PORT=$(clean_path "$PORT")
fi
if [ -n "$USERNAME" ]; then
    USERNAME=$(clean_path "$USERNAME")
fi
if [ -n "$PASSWORD" ]; then
    PASSWORD=$(clean_path "$PASSWORD")
fi
if [ -n "$LOG_ENABLED" ]; then
    LOG_ENABLED=$(clean_path "$LOG_ENABLED")
fi
if [ -n "$LOG_MAXSIZE" ]; then
    LOG_MAXSIZE=$(clean_path "$LOG_MAXSIZE")
fi
if [ -n "$LOG_MAXBACKUPS" ]; then
    LOG_MAXBACKUPS=$(clean_path "$LOG_MAXBACKUPS")
fi
if [ -n "$LOG_MAXAGE" ]; then
    LOG_MAXAGE=$(clean_path "$LOG_MAXAGE")
fi
if [ -n "$LOG_COMPRESS" ]; then
    LOG_COMPRESS=$(clean_path "$LOG_COMPRESS")
fi
if [ -n "$MULTICAST_IFACES" ]; then
    MULTICAST_IFACES=$(clean_path "$MULTICAST_IFACES")
fi
if [ -n "$MCAST_REJOIN_INTERVAL" ]; then
    MCAST_REJOIN_INTERVAL=$(clean_path "$MCAST_REJOIN_INTERVAL")
fi
if [ -n "$FCC_TYPE" ]; then
    FCC_TYPE=$(clean_path "$FCC_TYPE")
fi
if [ -n "$FCC_CACHE_SIZE" ]; then
    FCC_CACHE_SIZE=$(clean_path "$FCC_CACHE_SIZE")
fi
if [ -n "$FCC_LISTEN_PORT_MIN" ]; then
    FCC_LISTEN_PORT_MIN=$(clean_path "$FCC_LISTEN_PORT_MIN")
fi
if [ -n "$FCC_LISTEN_PORT_MAX" ]; then
    FCC_LISTEN_PORT_MAX=$(clean_path "$FCC_LISTEN_PORT_MAX")
fi
if [ -n "$UPSTREAM_INTERFACE" ]; then
    UPSTREAM_INTERFACE=$(clean_path "$UPSTREAM_INTERFACE")
fi
if [ -n "$UPSTREAM_INTERFACE_FCC" ]; then
    UPSTREAM_INTERFACE_FCC=$(clean_path "$UPSTREAM_INTERFACE_FCC")
fi

CONFIG_FILE="/etc/tvgate/config.yaml"

# 创建临时文件
TEMP_FILE=$(mktemp)

# 规范化布尔
normalize_bool() {
    val="$(echo "$1" | tr 'A-Z' 'a-z')"
    case "$val" in
        1|true|on|yes) echo "true" ;;
        0|false|off|no) echo "false" ;;
        *) echo "$1" ;;
    esac
}
if [ -n "$LOG_ENABLED" ]; then LOG_ENABLED="$(normalize_bool "$LOG_ENABLED")"; fi
if [ -n "$LOG_COMPRESS" ]; then LOG_COMPRESS="$(normalize_bool "$LOG_COMPRESS")"; fi

NEED_MULTICAST_UPDATE=0
if [ "${HAS_MULTICAST_IFACES:-0}" = "1" ] || \
   [ "${HAS_MCAST_REJOIN_INTERVAL:-0}" = "1" ] || \
   [ "${HAS_FCC_TYPE:-0}" = "1" ] || \
   [ "${HAS_FCC_CACHE_SIZE:-0}" = "1" ] || \
   [ "${HAS_FCC_LISTEN_PORT_MIN:-0}" = "1" ] || \
   [ "${HAS_FCC_LISTEN_PORT_MAX:-0}" = "1" ] || \
   [ "${HAS_UPSTREAM_INTERFACE:-0}" = "1" ] || \
   [ "${HAS_UPSTREAM_INTERFACE_FCC:-0}" = "1" ]; then
    NEED_MULTICAST_UPDATE=1
fi

write_multicast_section() {
    echo "multicast:"

    ifaces_csv="${MULTICAST_IFACES:-}"
    if [ -z "$ifaces_csv" ]; then
        echo "  multicast_ifaces: []"
    else
        echo "  multicast_ifaces:"
        old_ifs="$IFS"
        IFS=','
        set -- $ifaces_csv
        IFS="$old_ifs"
        for iface in "$@"; do
            iface="$(echo "$iface" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [ -n "$iface" ] && echo "    - $iface"
        done
    fi

    echo "  mcast_rejoin_interval: ${MCAST_REJOIN_INTERVAL:-0s}"
    echo "  fcc_type: ${FCC_TYPE:-huawei}"
    echo "  fcc_cache_size: ${FCC_CACHE_SIZE:-16386}"
    echo "  fcc_listen_port_min: ${FCC_LISTEN_PORT_MIN:-40000}"
    echo "  fcc_listen_port_max: ${FCC_LISTEN_PORT_MAX:-40100}"

    [ -n "${UPSTREAM_INTERFACE:-}" ] && echo "  upstream_interface: ${UPSTREAM_INTERFACE}"
    [ -n "${UPSTREAM_INTERFACE_FCC:-}" ] && echo "  upstream_interface_fcc: ${UPSTREAM_INTERFACE_FCC}"
}

update_multicast_section() {
    infile="$1"
    secfile="$2"
    awk -v secfile="$secfile" '
function printsec(    l) {
    while ((getline l < secfile) > 0) print l
    close(secfile)
}
BEGIN { in_sec=0; done=0 }
{
    if (!in_sec && $0 ~ /^[[:space:]]*multicast:[[:space:]]*$/) {
        printsec()
        done=1
        in_sec=1
        next
    }
    if (in_sec) {
        if ($0 ~ /^[A-Za-z0-9_]+:[[:space:]]*$/) {
            in_sec=0
            print $0
            next
        }
        next
    }
    print $0
}
END {
    if (!done) {
        print ""
        printsec()
    }
}
' "$infile" > "${infile}.new" && mv "${infile}.new" "$infile"
}

# 读取原文件内容并替换指定值
if [ -f "$CONFIG_FILE" ]; then
    # 逐行处理原文件
    CURRENT_SECTION=""
    WEB_PATH_FOUND=0
    WEB_USERNAME_FOUND=0
    WEB_PASSWORD_FOUND=0
    MONITOR_PATH_FOUND=0
    SERVER_PORT_FOUND=0
    LOG_ENABLED_FOUND=0
    LOG_FILE_FOUND=0
    LOG_MAXSIZE_FOUND=0
    LOG_MAXBACKUPS_FOUND=0
    LOG_MAXAGE_FOUND=0
    LOG_COMPRESS_FOUND=0

    while IFS= read -r line; do
        NEW_SECTION=""
        if echo "$line" | grep -q "^[[:space:]]*web:$"; then NEW_SECTION="web"; fi
        if echo "$line" | grep -q "^[[:space:]]*monitor:$"; then NEW_SECTION="monitor"; fi
        if echo "$line" | grep -q "^[[:space:]]*server:$"; then NEW_SECTION="server"; fi
        if echo "$line" | grep -q "^[[:space:]]*log:$"; then NEW_SECTION="log"; fi

        if [ -n "$NEW_SECTION" ]; then
            if [ "$CURRENT_SECTION" = "web" ]; then
                [ -n "$WEB_PATH" ] && [ "$WEB_PATH_FOUND" -eq 0 ] && echo "  path: $WEB_PATH"
                [ -n "$USERNAME" ] && [ "$WEB_USERNAME_FOUND" -eq 0 ] && echo "  username: $USERNAME"
                [ -n "$PASSWORD" ] && [ "$WEB_PASSWORD_FOUND" -eq 0 ] && echo "  password: $PASSWORD"
            elif [ "$CURRENT_SECTION" = "monitor" ]; then
                [ -n "$MONITOR_PATH" ] && [ "$MONITOR_PATH_FOUND" -eq 0 ] && echo "  path: $MONITOR_PATH"
            elif [ "$CURRENT_SECTION" = "server" ]; then
                [ -n "$PORT" ] && [ "$SERVER_PORT_FOUND" -eq 0 ] && echo "  port: $PORT"
            elif [ "$CURRENT_SECTION" = "log" ]; then
                [ -n "$LOG_ENABLED" ] && [ "$LOG_ENABLED_FOUND" -eq 0 ] && echo "  enabled: $LOG_ENABLED"
                [ -n "$LOG_FILE" ] && [ "$LOG_FILE_FOUND" -eq 0 ] && echo "  file: $LOG_FILE"
                [ -n "$LOG_MAXSIZE" ] && [ "$LOG_MAXSIZE_FOUND" -eq 0 ] && echo "  maxsize: $LOG_MAXSIZE"
                [ -n "$LOG_MAXBACKUPS" ] && [ "$LOG_MAXBACKUPS_FOUND" -eq 0 ] && echo "  maxbackups: $LOG_MAXBACKUPS"
                [ -n "$LOG_MAXAGE" ] && [ "$LOG_MAXAGE_FOUND" -eq 0 ] && echo "  maxage: $LOG_MAXAGE"
                [ -n "$LOG_COMPRESS" ] && [ "$LOG_COMPRESS_FOUND" -eq 0 ] && echo "  compress: $LOG_COMPRESS"
            fi
            CURRENT_SECTION="$NEW_SECTION"
            WEB_PATH_FOUND=0; WEB_USERNAME_FOUND=0; WEB_PASSWORD_FOUND=0
            MONITOR_PATH_FOUND=0; SERVER_PORT_FOUND=0
            LOG_ENABLED_FOUND=0; LOG_FILE_FOUND=0; LOG_MAXSIZE_FOUND=0; LOG_MAXBACKUPS_FOUND=0; LOG_MAXAGE_FOUND=0; LOG_COMPRESS_FOUND=0
            echo "$line"
            continue
        fi

        case "$CURRENT_SECTION" in
            web)
                if echo "$line" | grep -q "^\s*path:\s.*" && [ -n "$WEB_PATH" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*path:[[:space:]]*\).*|\1$WEB_PATH|"
                    WEB_PATH_FOUND=1
                elif echo "$line" | grep -q "^\s*username:\s.*" && [ -n "$USERNAME" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*username:[[:space:]]*\).*|\1$USERNAME|"
                    WEB_USERNAME_FOUND=1
                elif echo "$line" | grep -q "^\s*password:\s.*" && [ -n "$PASSWORD" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*password:[[:space:]]*\).*|\1$PASSWORD|"
                    WEB_PASSWORD_FOUND=1
                else
                    echo "$line"
                fi
                ;;
            monitor)
                if echo "$line" | grep -q "^\s*path:\s.*" && [ -n "$MONITOR_PATH" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*path:[[:space:]]*\).*|\1$MONITOR_PATH|"
                    MONITOR_PATH_FOUND=1
                else
                    echo "$line"
                fi
                ;;
            server)
                if echo "$line" | grep -q "^\s*port:\s.*" && [ -n "$PORT" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*port:[[:space:]]*\).*|\1$PORT|"
                    SERVER_PORT_FOUND=1
                else
                    echo "$line"
                fi
                ;;
            log)
                if echo "$line" | grep -q "^\s*enabled:\s.*" && [ -n "$LOG_ENABLED" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*enabled:[[:space:]]*\).*|\1$LOG_ENABLED|"
                    LOG_ENABLED_FOUND=1
                elif echo "$line" | grep -q "^\s*file:\s.*" && [ -n "$LOG_FILE" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*file:[[:space:]]*\).*|\1$LOG_FILE|"
                    LOG_FILE_FOUND=1
                elif echo "$line" | grep -q "^\s*maxsize:\s.*" && [ -n "$LOG_MAXSIZE" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*maxsize:[[:space:]]*\).*|\1$LOG_MAXSIZE|"
                    LOG_MAXSIZE_FOUND=1
                elif echo "$line" | grep -q "^\s*maxbackups:\s.*" && [ -n "$LOG_MAXBACKUPS" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*maxbackups:[[:space:]]*\).*|\1$LOG_MAXBACKUPS|"
                    LOG_MAXBACKUPS_FOUND=1
                elif echo "$line" | grep -q "^\s*maxage:\s.*" && [ -n "$LOG_MAXAGE" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*maxage:[[:space:]]*\).*|\1$LOG_MAXAGE|"
                    LOG_MAXAGE_FOUND=1
                elif echo "$line" | grep -q "^\s*compress:\s.*" && [ -n "$LOG_COMPRESS" ]; then
                    echo "$line" | sed "s|^\([[:space:]]*compress:[[:space:]]*\).*|\1$LOG_COMPRESS|"
                    LOG_COMPRESS_FOUND=1
                else
                    echo "$line"
                fi
                ;;
            *)
                echo "$line"
                ;;
        esac
    done < "$CONFIG_FILE" > "$TEMP_FILE"

    # 结束时对当前分节补足缺失键
    if [ "$CURRENT_SECTION" = "web" ]; then
        [ -n "$WEB_PATH" ] && [ "$WEB_PATH_FOUND" -eq 0 ] && echo "  path: $WEB_PATH" >> "$TEMP_FILE"
        [ -n "$USERNAME" ] && [ "$WEB_USERNAME_FOUND" -eq 0 ] && echo "  username: $USERNAME" >> "$TEMP_FILE"
        [ -n "$PASSWORD" ] && [ "$WEB_PASSWORD_FOUND" -eq 0 ] && echo "  password: $PASSWORD" >> "$TEMP_FILE"
    elif [ "$CURRENT_SECTION" = "monitor" ]; then
        [ -n "$MONITOR_PATH" ] && [ "$MONITOR_PATH_FOUND" -eq 0 ] && echo "  path: $MONITOR_PATH" >> "$TEMP_FILE"
    elif [ "$CURRENT_SECTION" = "server" ]; then
        [ -n "$PORT" ] && [ "$SERVER_PORT_FOUND" -eq 0 ] && echo "  port: $PORT" >> "$TEMP_FILE"
    elif [ "$CURRENT_SECTION" = "log" ]; then
        [ -n "$LOG_ENABLED" ] && [ "$LOG_ENABLED_FOUND" -eq 0 ] && echo "  enabled: $LOG_ENABLED" >> "$TEMP_FILE"
        [ -n "$LOG_FILE" ] && [ "$LOG_FILE_FOUND" -eq 0 ] && echo "  file: $LOG_FILE" >> "$TEMP_FILE"
        [ -n "$LOG_MAXSIZE" ] && [ "$LOG_MAXSIZE_FOUND" -eq 0 ] && echo "  maxsize: $LOG_MAXSIZE" >> "$TEMP_FILE"
        [ -n "$LOG_MAXBACKUPS" ] && [ "$LOG_MAXBACKUPS_FOUND" -eq 0 ] && echo "  maxbackups: $LOG_MAXBACKUPS" >> "$TEMP_FILE"
        [ -n "$LOG_MAXAGE" ] && [ "$LOG_MAXAGE_FOUND" -eq 0 ] && echo "  maxage: $LOG_MAXAGE" >> "$TEMP_FILE"
        [ -n "$LOG_COMPRESS" ] && [ "$LOG_COMPRESS_FOUND" -eq 0 ] && echo "  compress: $LOG_COMPRESS" >> "$TEMP_FILE"
    fi
else
    # 如果配置文件不存在，创建默认配置
    cat > "$TEMP_FILE" << EOF
server:
  #监听端口
  port: 8888
# 监控配置
monitor:
  path: "/status" # 状态信息

# 配置文件编辑接口
web:
  enabled: true
  username: admin
  password: admin
  path: /web/ # 自定义路径
EOF
    # 标记为需要后续添加web配置
    NEED_DEFAULT_CONFIG=1
fi

# 如果需要默认配置，或web/monitor部分不存在，添加它们
if [ "$NEED_DEFAULT_CONFIG" != "1" ]; then
    # 检查是否已存在web和monitor部分
    WEB_SECTION_EXISTS=$(grep -c "^[[:space:]]*web:" "$TEMP_FILE")
    MONITOR_SECTION_EXISTS=$(grep -c "^[[:space:]]*monitor:" "$TEMP_FILE")
    SERVER_SECTION_EXISTS=$(grep -c "^[[:space:]]*server:" "$TEMP_FILE")
    LOG_SECTION_EXISTS=$(grep -c "^[[:space:]]*log:" "$TEMP_FILE")
    
    # 如果web部分不存在，但需要设置web配置，添加web部分
    if [ "$WEB_SECTION_EXISTS" = "0" ] && ([ -n "$WEB_PATH" ] || [ -n "$USERNAME" ] || [ -n "$PASSWORD" ]); then
        {
            cat "$TEMP_FILE"
            echo ""
            echo "web:"
            echo "  enabled: true"
            echo "  username: ${USERNAME:-admin}"
            echo "  password: ${PASSWORD:-admin}"
            echo "  path: ${WEB_PATH:-/web/}"
        } > "${TEMP_FILE}.new" && mv "${TEMP_FILE}.new" "$TEMP_FILE"
    fi
    
    # 如果monitor部分不存在，但需要设置monitor配置，添加monitor部分
    if [ "$MONITOR_SECTION_EXISTS" = "0" ] && [ -n "$MONITOR_PATH" ]; then
        {
            cat "$TEMP_FILE"
            echo ""
            echo "monitor:"
            echo "  path: ${MONITOR_PATH:-/status}"
        } > "${TEMP_FILE}.new" && mv "${TEMP_FILE}.new" "$TEMP_FILE"
    fi
    
    # 如果server部分不存在，但需要设置端口，添加server部分
    if [ "$SERVER_SECTION_EXISTS" = "0" ] && [ -n "$PORT" ]; then
        {
            echo "server:"
            echo "  #监听端口"
            echo "  port: ${PORT:-8888}"
            echo ""
            cat "$TEMP_FILE"
        } > "${TEMP_FILE}.new" && mv "${TEMP_FILE}.new" "$TEMP_FILE"
    fi
    if [ "$LOG_SECTION_EXISTS" = "0" ] && ([ -n "$LOG_ENABLED" ] || [ -n "$LOG_FILE" ] || [ -n "$LOG_MAXSIZE" ] || [ -n "$LOG_MAXBACKUPS" ] || [ -n "$LOG_MAXAGE" ] || [ -n "$LOG_COMPRESS" ]); then
        {
            cat "$TEMP_FILE"
            echo ""
            echo "log:"
            [ -n "$LOG_ENABLED" ] && echo "  enabled: ${LOG_ENABLED}"
            [ -n "$LOG_FILE" ] && echo "  file: ${LOG_FILE}"
            [ -n "$LOG_MAXSIZE" ] && echo "  maxsize: ${LOG_MAXSIZE}"
            [ -n "$LOG_MAXBACKUPS" ] && echo "  maxbackups: ${LOG_MAXBACKUPS}"
            [ -n "$LOG_MAXAGE" ] && echo "  maxage: ${LOG_MAXAGE}"
            [ -n "$LOG_COMPRESS" ] && echo "  compress: ${LOG_COMPRESS}"
        } > "${TEMP_FILE}.new" && mv "${TEMP_FILE}.new" "$TEMP_FILE"
    fi
fi

if [ "$NEED_MULTICAST_UPDATE" = "1" ]; then
    MULTICAST_SECTION_FILE="$(mktemp)"
    write_multicast_section > "$MULTICAST_SECTION_FILE"
    update_multicast_section "$TEMP_FILE" "$MULTICAST_SECTION_FILE"
    rm -f "$MULTICAST_SECTION_FILE"
fi

mv "$TEMP_FILE" "$CONFIG_FILE"

echo "YAML configuration updated successfully"
