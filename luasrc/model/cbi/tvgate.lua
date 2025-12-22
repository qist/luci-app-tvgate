local fs = require "nixio.fs"
local sys = require "luci.sys"

m = Map("tvgate", translate("TVGate"), translate("TVGate is a high-performance local network resource forwarding and proxy tool."))

s = m:section(TypedSection, "tvgate", translate("Settings"))
s.anonymous = true

enabled = s:option(Flag, "enabled", translate("Enable"), translate("Enable TVGate service"))

proxy = s:option(Value, "proxy", translate("Download Proxy"), 
	translate("Proxy for downloading TVGate binary (e.g., https://hk.gh-proxy.com/)"))
proxy.placeholder = "https://hk.gh-proxy.com/"
proxy.rmempty = true

download_url = s:option(Value, "download_url", translate("Download URL"),
	translate("URL for downloading TVGate binary (leave empty to auto-detect based on CPU architecture)"))
download_url.placeholder = "https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-amd64.zip"
download_url.rmempty = true

listen_port = s:option(Value, "listen_port", translate("Listen Port"),
	translate("Port for TV streaming service"))
listen_port.datatype = "port"
listen_port.default = 8888

config_port = s:option(Value, "config_port", translate("Config Port"),
	translate("Port for web configuration interface"))
config_port.datatype = "port"
config_port.default = 8889

s = m:section(TypedSection, "tvgate", translate("Status"))
s.anonymous = true

local btn = s:option(Button, "_download", translate("Download/Update Binary"))
btn.inputstyle = "apply"
btn.description = translate("Download or update the TVGate binary file")
btn.write = function()
	luci.http.redirect(luci.dispatcher.build_url("admin/services/tvgate/download"))
end

local status = s:option(DummyValue, "_status", translate("Service Status"))
status.template = "tvgate/status"
status.value = translate("Collecting data...")

return m