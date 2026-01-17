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
-- 基础设置
-- =========================
s = m:section(TypedSection, "tvgate", i18n.translate("Settings"))
s.addremove = false
s.anonymous = true

-- 创建配置文件（如果不存在）
local tvgate_config_dir = "/etc/config/tvgate"
if not fs or not fs.access(tvgate_config_dir) then
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
