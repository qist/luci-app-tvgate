local ok_fs, fs_mod = pcall(require, "nixio.fs")
if not ok_fs then ok_fs, fs_mod = pcall(require, "luci.fs") end
local fs = fs_mod
local sys  = require "luci.sys"
local uci  = require "luci.model.uci".cursor()
local utl  = require "luci.util"
local i18n = require "luci.i18n"

m = Map("tvgate",
    i18n.translate("TVGate"),
    i18n.translate([[TVGate is a high-performance local network resource forwarding and proxy tool.]])
)

-- =========================
-- 读取 YAML 配置
-- =========================
local function read_yaml_config()
    local yaml_path = "/etc/tvgate/config.yaml"

    local config = {
        server  = { port = "8888" },
        web     = { path = "/web/", username = "admin", password = "admin", enabled = "true" },
        monitor = { path = "/status" },
        log     = { enabled = "true", file = "", maxsize = "10", maxbackups = "10", maxage = "28", compress = "false" }
    }

    if not fs.access(yaml_path) then
        return config
    end

    local f = io.open(yaml_path, "r")
    if not f then
        return config
    end

    local content = f:read("*all")
    f:close()

    local current_section = nil

    for line in content:gmatch("[^\r\n]+") do
        local clean = line:gsub("#.*$", ""):gsub("^%s*", "")
        if clean ~= "" then
            local section = clean:match("^(%w+):%s*$")
            if section then
                current_section = section
            else
                local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
                if key and value then
                    if current_section == "server" and key == "port" then
                        config.server.port = value
                    elseif current_section == "web" then
                        if key == "path" then
                            config.web.path = value
                        elseif key == "username" then
                            config.web.username = value
                        elseif key == "password" then
                            config.web.password = value
                        elseif key == "enabled" then
                            config.web.enabled = value
                        end
                    elseif current_section == "monitor" and key == "path" then
                        config.monitor.path = value
                    elseif current_section == "log" then
                        if key == "enabled" then
                            config.log.enabled = value
                        elseif key == "file" then
                            config.log.file = value
                        elseif key == "maxsize" then
                            config.log.maxsize = value
                        elseif key == "maxbackups" then
                            config.log.maxbackups = value
                        elseif key == "maxage" then
                            config.log.maxage = value
                        elseif key == "compress" then
                            config.log.compress = value
                        end
                    end
                end
            end
        end
    end

    return config
end


-- =========================
-- 基础设置
-- =========================
s = m:section(TypedSection, "tvgate", i18n.translate("Settings"))
s.addremove = false
s.anonymous = true

-- 创建配置文件（如果不存在）
local tvgate_config_dir = "/etc/config/tvgate"
if not fs or not fs.access(tvgate_config_dir) then
    sys.call("touch /etc/config/tvgate >/dev/null 2>&1")
    -- 设置默认值
    uci:set("tvgate", "tvgate", "enabled", "0")
    uci:commit("tvgate")
end

s:option(Flag, "enabled", i18n.translate("Enable"))

proxy = s:option(Value, "proxy", i18n.translate("Download Proxy"))
proxy.placeholder = "https://hk.gh-proxy.com/"
proxy.rmempty = true

-- 隐藏Download URL字段，因为一般不常变化
-- download_url = s:option(Value, "download_url", i18n.translate("Download URL"))
-- download_url.placeholder = "https://github.com/qist/tvgate/releases"
-- download_url.rmempty = true


-- =========================
-- 状态页
-- =========================
st = m:section(TypedSection, "tvgate", i18n.translate("Status"))
st.anonymous = true

btn = st:option(DummyValue, "_download", i18n.translate("Download / Update Binary"))
btn.template = "tvgate/status"

m.on_after_commit = function(self)
    -- 修复服务重启命令，兼容OpenWrt和ImmortalWrt
    local restart_cmd = "/etc/init.d/tvgate restart >/dev/null 2>&1"
    -- 检查是否有systemctl命令（通常在ImmortalWrt中可用）
    local has_systemctl = sys.call("command -v systemctl >/dev/null 2>&1") == 0
    if has_systemctl then
        restart_cmd = restart_cmd .. " && /etc/init.d/tvgate stop >/dev/null 2>&1; /etc/init.d/tvgate start >/dev/null 2>&1"
    else
        restart_cmd = restart_cmd .. " &"
    end
    sys.call(restart_cmd)
end

return m
