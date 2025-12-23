local fs = require "nixio.fs"
local sys = require "luci.sys"

m = Map("tvgate", translate("TVGate"), translate("TVGate is a high-performance local network resource forwarding and proxy tool."))

m.on_after_commit = function(self)
    local uci = require "luci.model.uci".cursor()

    local port = uci:get("tvgate", "@tvgate[0]", "listen_port") or "8888"

    luci.sys.call(string.format(
        "/usr/bin/tvgate-config-update.sh %s >/dev/null 2>&1",
        port
    ))
	luci.sys.call("/etc/init.d/tvgate restart >/dev/null 2>&1 &")
end

s = m:section(TypedSection, "tvgate", translate("Settings"))
s.addremove = false
s.anonymous = true

enabled = s:option(Flag, "enabled", translate("Enable"), translate("Enable TVGate service"))

proxy = s:option(Value, "proxy", translate("Download Proxy"), 
	translate("Proxy for downloading TVGate binary (e.g., https://hk.gh-proxy.com/)"))
proxy.placeholder = "https://hk.gh-proxy.com/"
proxy.rmempty = true

download_url = s:option(Value, "download_url", translate("Download URL"),
	translate("URL for downloading TVGate binary (leave empty to auto-detect based on CPU architecture)"))
download_url.placeholder = "https://github.com/qist/tvgate/releases (Auto-select by CPU architecture)"
download_url.rmempty = true

listen_port = s:option(Value, "listen_port", translate("Listen Port"),
	translate("Port for TV streaming service"))
listen_port.datatype = "port"
listen_port.default = 8888

s = m:section(TypedSection, "tvgate", translate("Status"))
s.anonymous = true


local btn = s:option(DummyValue, "_download", translate("Download/Update Binary"))
btn.template = "tvgate/status"

return m