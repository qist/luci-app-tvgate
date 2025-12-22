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
	
	-- Execute download script and capture result
	local result_code = sys.call("/usr/bin/tvgate-download.sh >/tmp/tvgate-download.log 2>&1")
	local success = result_code == 0
	
	-- Read log with error handling
	local log_content = ""
	if nixio.fs.access("/tmp/tvgate-download.log") then
		log_content = sys.exec("cat /tmp/tvgate-download.log 2>/dev/null") or "Failed to read log file"
	else
		log_content = "Log file was not created"
	end
	
	-- Prepare response
	local ret = {
		result = success,
		log = log_content,
		exit_code = result_code
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
		default_url = "https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-" .. detected_arch .. ".zip"
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(response)
end

function act_tvgate_config()
	local sys = require "luci.sys"
	local json = require "luci.jsonc"
	
	local config_path = "/etc/tvgate/config.yaml"
	local config_data = {
		web_path = "/web/",
		monitor_path = "/status",
		error = nil
	}
	
	-- Check if config file exists
	if not nixio.fs.access(config_path) then
		config_data.error = "Config file does not exist: " .. config_path
		luci.http.prepare_content("application/json")
		luci.http.write_json(config_data)
		return
	end
	
	-- Try to read the config file
	local file, err = io.open(config_path, "r")
	if not file then
		config_data.error = "Cannot open config file: " .. (err or "Unknown error")
		luci.http.prepare_content("application/json")
		luci.http.write_json(config_data)
		return
	end
	
	local content = file:read("*all")
	file:close()
	
	-- Validate content was read
	if not content then
		config_data.error = "Failed to read config file content"
		luci.http.prepare_content("application/json")
		luci.http.write_json(config_data)
		return
	end
	
	-- Parse the configuration
	config_data = parse_tvgate_config(content)
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(config_data)
end

function parse_tvgate_config(content)
	local config = {
		web_path = "/web/",
		monitor_path = "/status",
		error = nil
	}
	
	-- Handle empty or missing content
	if not content or content == "" then
		config.error = "Empty configuration content"
		return config
	end
	
	-- Simple parser for the specific fields we need
	local in_web_section = false
	local in_monitor_section = false
	
	for line in content:gmatch("[^\r\n]+") do
		-- Skip comments and empty lines
		line = line:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line == "" then continue end
		
		-- Detect sections
		if line:match("^web:%s*$") then
			in_web_section = true
			in_monitor_section = false
		elseif line:match("^monitor:%s*$") then
			in_monitor_section = true
			in_web_section = false
		elseif line:match("^%w+:") and not line:match("^(path|address|port):") then
			-- New section starting
			in_web_section = false
			in_monitor_section = false
		end
		
		-- Match web.path (with various formats)
		local web_path = line:match("^%s*path:%s*(.-)%s*$")
		if web_path and (in_web_section or content:match("\n%s*web:%s*\n.*\n%s*path:" .. web_path)) then
			config.web_path = web_path:gsub("\"", ""):gsub("'", ""):gsub("#.+$", ""):gsub("%s+$", "")
		end
		
		-- Match monitor.path (direct assignment)
		local monitor_path = line:match("^%s*monitor:%s*path:%s*(.-)%s*$")
		if monitor_path then
			config.monitor_path = monitor_path:gsub("\"", ""):gsub("'", ""):gsub("#.+$", ""):gsub("%s+$", "")
		end
		
		-- Match monitor.path (in monitor section)
		local sec_path = line:match("^%s*path:%s*(.-)%s*$")
		if sec_path and in_monitor_section then
			config.monitor_path = sec_path:gsub("\"", ""):gsub("'", ""):gsub("#.+$", ""):gsub("%s+$", "")
		end
	end
	::continue::
	end
	
	return config
end