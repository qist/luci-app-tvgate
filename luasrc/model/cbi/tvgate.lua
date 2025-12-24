local ok_fs, fs_mod = pcall(require, "nixio.fs")
if not ok_fs then ok_fs, fs_mod = pcall(require, "luci.fs") end
local fs = fs_mod
local sys  = require "luci.sys"
local uci  = require "luci.model.uci".cursor()
local utl  = require "luci.util"
local i18n = require "luci.i18n"

m = Map("tvgate",
    i18n.translate("TVGate"),
    i18n.translate([[TVGate is a high-performance local network resource forwarding and proxy tool.

<div class="cbi-section" style="margin-bottom: 10px;">
  <div style="padding:12px;border:1px solid #cce5ff;background:#e9f7ff;color:#084b8a;border-radius:6px;">
    <div style="font-weight:600;margin-bottom:6px;">使用提示</div>
    <ul style="margin:0;padding-left:18px;line-height:1.6;">
      <li>首次安装请点击"Download / Update Binary" 按钮下载并启动 TVGate 二进制。</li>
      <li>然后可以修改配置。</li>
      <li>保存配置后请手动刷新页面，确认web显示正常。</li>
    </ul>
  </div>
</div>]])
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

download_url = s:option(Value, "download_url", i18n.translate("Download URL"))
download_url.placeholder = "https://github.com/qist/tvgate/releases"
download_url.rmempty = true

-- =========================
-- Web 设置（通过脚本更新 YAML）
-- =========================
local cfg = read_yaml_config()

ws = m:section(TypedSection, "tvgate", i18n.translate("Web Settings"))
ws.addremove = false
ws.anonymous = true
ws.sectionname = "web_settings"

web_path = ws:option(Value, "web_path", i18n.translate("Web Path"))
web_path.default = cfg.web.path
web_path.placeholder = "/web/"
web_path.description = i18n.translate("Web path prefix, e.g., /web/")
-- 不写入UCI配置
web_path.write = function(self, section, value)
end
web_path.remove = function(self, section)
end

monitor_path = ws:option(Value, "monitor_path", i18n.translate("Monitor Path"))
monitor_path.default = cfg.monitor.path
monitor_path.placeholder = "/status"
monitor_path.description = i18n.translate("Monitor endpoint path, e.g., /status")
-- 不写入UCI配置
monitor_path.write = function(self, section, value)
end
monitor_path.remove = function(self, section)
end

port = ws:option(Value, "port", i18n.translate("Port"))
port.default = cfg.server.port
port.placeholder = "8888"
port.description = i18n.translate("Streaming port in server section")
-- 不写入UCI配置
port.write = function(self, section, value)
end
port.remove = function(self, section)
end

username = ws:option(Value, "username", i18n.translate("Username"))
username.default = cfg.web.username
username.placeholder = "admin"
username.description = i18n.translate("Admin username for Web UI")
-- 不写入UCI配置
username.write = function(self, section, value)
end
username.remove = function(self, section)
end

password = ws:option(Value, "password", i18n.translate("Password"))
password.password = true
password.default = cfg.web.password
password.placeholder = "admin"
password.description = i18n.translate("Admin password for Web UI")
password.write = function(self, section, value)
end
password.remove = function(self, section)
end

log_enabled = ws:option(Flag, "log_enabled", i18n.translate("Log Enabled"))
log_enabled.default = (cfg.log.enabled == "true" or cfg.log.enabled == "1") and log_enabled.enabled or log_enabled.disabled
log_enabled.description = i18n.translate("Enable log output")
log_enabled.write = function(self, section, value)
end
log_enabled.remove = function(self, section)
end

log_file = ws:option(Value, "log_file", i18n.translate("Log File"))
log_file.default = cfg.log.file
log_file.placeholder = ""
log_file.description = i18n.translate("Empty for stdout, otherwise file path")
log_file.write = function(self, section, value)
end
log_file.remove = function(self, section)
end

log_maxsize = ws:option(Value, "log_maxsize", i18n.translate("Log Max Size (MB)"))
log_maxsize.default = cfg.log.maxsize
log_maxsize.placeholder = "10"
log_maxsize.description = i18n.translate("Rotate when max size reached (MB)")
log_maxsize.write = function(self, section, value)
end
log_maxsize.remove = function(self, section)
end

log_maxbackups = ws:option(Value, "log_maxbackups", i18n.translate("Log Max Backups"))
log_maxbackups.default = cfg.log.maxbackups
log_maxbackups.placeholder = "10"
log_maxbackups.description = i18n.translate("Number of compressed backups to keep")
log_maxbackups.write = function(self, section, value)
end
log_maxbackups.remove = function(self, section)
end

log_maxage = ws:option(Value, "log_maxage", i18n.translate("Log Max Age (days)"))
log_maxage.default = cfg.log.maxage
log_maxage.placeholder = "28"
log_maxage.description = i18n.translate("Retention days for log files")
log_maxage.write = function(self, section, value)
end
log_maxage.remove = function(self, section)
end

log_compress = ws:option(Flag, "log_compress", i18n.translate("Log Compress"))
log_compress.default = (cfg.log.compress == "true" or cfg.log.compress == "1") and log_compress.enabled or log_compress.disabled
log_compress.description = i18n.translate("Compress rotated log files")
log_compress.write = function(self, section, value)
end
log_compress.remove = function(self, section)
end

-- =========================
-- 状态页
-- =========================
st = m:section(TypedSection, "tvgate", i18n.translate("Status"))
st.anonymous = true

btn = st:option(DummyValue, "_download", i18n.translate("Download / Update Binary"))
btn.template = "tvgate/status"

m.on_after_commit = function(self)
    local sids = ws:cfgsections()
    local sid = (sids and sids[1]) or ""
    local function fv(name)
        return self:formvalue("cbid.tvgate." .. sid .. "." .. name)
    end
    local web_path = fv("web_path")
    local monitor_path = fv("monitor_path")
    local port = fv("port")
    local username = fv("username")
    local password = fv("password")
    local log_enabled_val = fv("log_enabled")
    local log_file_val = fv("log_file")
    local log_maxsize_val = fv("log_maxsize")
    local log_maxbackups_val = fv("log_maxbackups")
    local log_maxage_val = fv("log_maxage")
    local log_compress_val = fv("log_compress")
    local function boolstr(x)
        if not x then return nil end
        local s = tostring(x):lower()
        if s == "1" or s == "on" or s == "true" or s == "yes" then return "true" end
        if s == "0" or s == "off" or s == "false" or s == "no" then return "false" end
        return s
    end

    local cmd = "/usr/bin/tvgate-update-yaml.sh"
    if web_path then cmd = cmd .. " --web-path '" .. web_path:gsub("'", "'\"'\"'") .. "'" end
    if monitor_path then cmd = cmd .. " --monitor-path '" .. monitor_path:gsub("'", "'\"'\"'") .. "'" end
    if port then cmd = cmd .. " --port '" .. port:gsub("'", "'\"'\"'") .. "'" end
    if username then cmd = cmd .. " --username '" .. username:gsub("'", "'\"'\"'") .. "'" end
    if password then cmd = cmd .. " --password '" .. password:gsub("'", "'\"'\"'") .. "'" end
    local be = boolstr(log_enabled_val)
    local bc = boolstr(log_compress_val)
    if be then cmd = cmd .. " --log-enabled '" .. be:gsub("'", "'\"'\"'") .. "'" end
    if log_file_val then cmd = cmd .. " --log-file '" .. log_file_val:gsub("'", "'\"'\"'") .. "'" end
    if log_maxsize_val then cmd = cmd .. " --log-maxsize '" .. log_maxsize_val:gsub("'", "'\"'\"'") .. "'" end
    if log_maxbackups_val then cmd = cmd .. " --log-maxbackups '" .. log_maxbackups_val:gsub("'", "'\"'\"'") .. "'" end
    if log_maxage_val then cmd = cmd .. " --log-maxage '" .. log_maxage_val:gsub("'", "'\"'\"'") .. "'" end
    if bc then cmd = cmd .. " --log-compress '" .. bc:gsub("'", "'\"'\"'") .. "'" end

    sys.call(cmd .. " >/dev/null 2>&1")
    
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
