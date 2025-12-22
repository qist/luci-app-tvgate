module("luci.controller.tvgate", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/tvgate") then
		return
	end
	
	entry({"admin", "services", "tvgate"}, alias("admin", "services", "tvgate", "config"), _("TVGate"), 30).dependent = true
	entry({"admin", "services", "tvgate", "config"}, cbi("tvgate"), _("Configuration"), 10).leaf = true
	entry({"admin", "services", "tvgate", "status"}, call("act_status")).leaf = true
	entry({"admin", "services", "tvgate", "download"}, call("act_download")).leaf = true
	entry({"admin", "services", "tvgate", "detect_arch"}, call("act_detect_arch")).leaf = true
	entry({"admin", "services", "tvgate", "tvgate_config"}, call("act_tvgate_config")).leaf = true
end

function act_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	
	local status = {
		running = sys.call("pidof TVGate >/dev/null") == 0,
		enabled = sys.call("iptables -L | grep -q \"tvgate\"") == 0 or uci:get("tvgate", "tvgate", "enabled") == "1",
		binary_exists = nixio.fs.access("/usr/bin/tvgate/TVGate"),
		port = uci:get("tvgate", "tvgate", "listen_port") or "8888"
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end

function act_download()
	local sys = require "luci.sys"
	
	local ret = {
		result = sys.call("/usr/bin/tvgate-download.sh >/tmp/tvgate-download.log 2>&1") == 0,
		log = sys.exec("cat /tmp/tvgate-download.log")
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(ret)
	
	-- Clean up log file
	sys.call("rm -f /tmp/tvgate-download.log")
end

function act_detect_arch()
	local sys = require "luci.sys"
	local arch = sys.exec("uname -m"):gsub("%s+", "")
	
	local arch_mapping = {
		x86_64 = "amd64",
		aarch64 = "arm64",
		armv7l = "armv7",
		mips = "mips",
		mipsle = "mipsle"
	}
	
	local detected_arch = arch_mapping[arch] or "amd64"
	
	local response = {
		arch = arch,
		detected_arch = detected_arch,
		default_url = "https://github.com/qist/tvgate/releases/download/latest/TVGate-linux-" .. detected_arch .. ".zip"
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(response)
end

function act_tvgate_config()
	local sys = require "luci.sys"
	local json = require "luci.jsonc"
	
	local config_path = "/etc/tvgate/config.yaml"
	local config_data = {}
	
	-- Check if config file exists
	if nixio.fs.access(config_path) then
		local file = io.open(config_path, "r")
		if file then
			local content = file:read("*all")
			file:close()
			
			-- Parse YAML-like content (simplified approach)
			config_data = parse_tvgate_config(content)
		end
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(config_data)
end

function parse_tvgate_config(content)
	local config = {}
	
	-- Simple parser for the specific fields we need
	for line in content:gmatch("[^\r\n]+") do
		-- Match web.path
		local path = line:match("^%s*path:%s*(.+)")
		if path then
			config.web_path = path:gsub("\"", ""):gsub("'", "")
		end
		
		-- Match monitor.path
		local monitor_path = line:match("^%s*monitor:%s*path:%s*(.+)")
		if monitor_path then
			config.monitor_path = monitor_path:gsub("\"", ""):gsub("'", "")
		end
		
		-- More robust matcher for nested monitor.path
		if not config.monitor_path then
			local monitor_path = line:match("^%s*path:%s*(.-)%s*$")
			if monitor_path and content:match("monitor:") and line:match("^%s*path:") then
				config.monitor_path = monitor_path:gsub("\"", ""):gsub("'", "")
			end
		end
	end
	
	-- Set defaults if not found
	if not config.web_path then
		config.web_path = "/web/"
	end
	
	if not config.monitor_path then
		config.monitor_path = "/status"
	end
	
	return config
end