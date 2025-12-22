local sys = require "luci.sys"
local fs = require "nixio.fs"

m = Map("tvgate", translate("TVGate"), translate("TVGate is a high-performance local network resource forwarding and proxy tool."))

m.on_after_commit = function(self)
	luci.sys.call("/etc/init.d/tvgate reload")
end

s = m:section(TypedSection, "tvgate", translate("Settings"))
s.addremove = false
s.anonymous = true

enabled = s:option(Flag, "enabled", translate("Enable"), translate("Enable TVGate service"))

proxy = s:option(Value, "proxy", translate("Download Proxy"),
	translate("Proxy for downloading TVGate binary (e.g., https://hk.gh-proxy.com)"))
proxy.placeholder = "https://hk.gh-proxy.com"
proxy.rmempty = true

download_url = s:option(Value, "download_url", translate("Download URL"),
	translate("URL for downloading TVGate binary (leave empty to auto-detect based on CPU architecture)"))
download_url.placeholder = "https://github.com/qist/tvgate/releases/latest/download (Auto-select by CPU architecture)"
download_url.rmempty = true

listen_port = s:option(Value, "listen_port", translate("Listen Port"), translate("Port for TV streaming service"))
listen_port.datatype = "port"
listen_port.default = 8888

s = m:section(TypedSection, "tvgate", translate("Status"))
s.addremove = false
s.anonymous = true

download = s:option(Button, "_download", translate("Download/Update Binary"), translate("Download or update the TVGate binary file"))
download.inputstyle = "apply"

function download.write(self, section)
	-- We don't actually write to uci here, just trigger the download
	luci.http.redirect(luci.dispatcher.build_url("admin/services/tvgate/config"))
end

binary_status = s:option(DummyValue, "_binary_status", translate("Binary Status"))

function binary_status.cfgvalue(self, section)
	if fs.access("/usr/bin/tvgate/TVGate") then
		return translate("Installed")
	else
		return translate("Not installed")
	end
end

return m