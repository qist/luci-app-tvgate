module("luci.controller.tvgate", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/tvgate") then
		return
	end

	entry(
		{"admin", "services", "tvgate"},
		alias("admin", "services", "tvgate", "config"),
		_("TVGate"),
		30
	).dependent = true

	entry(
		{"admin", "services", "tvgate", "config"},
		cbi("tvgate"),
		_("Configuration"),
		10
	).leaf = true

	entry(
		{"admin", "services", "tvgate", "status"},
		call("act_status")
	).leaf = true

	entry(
		{"admin", "services", "tvgate", "download"},
		call("act_download")
	).leaf = true

	entry(
		{"admin", "services", "tvgate", "detect_arch"},
		call("act_detect_arch")
	).leaf = true

	entry(
		{"admin", "services", "tvgate", "tvgate_config"},
		call("act_tvgate_config")
	).leaf = true
end

-- =====================
-- status
-- =====================
function act_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()

	-- 从 YAML 配置文件中读取端口信息
	local port = "8888" -- 默认端口
	local yaml_config_path = "/etc/tvgate/config.yaml"
	
	if nixio.fs.access(yaml_config_path) then
		local f = io.open(yaml_config_path, "r")
		if f then
			local content = f:read("*all")
			f:close()
			
			-- 查找端口配置
			for line in content:gmatch("[^\r\n]+") do
				local p = line:match("^%s*port:%s*(%d+)")
				if p then
					port = p
					break
				end
			end
		end
	end

	local status = {
		-- 优先用 procd pid 文件检测，再用 pidof 兜底
		running = (nixio.fs.access("/var/run/tvgate.pid") and sys.call("kill -0 $(cat /var/run/tvgate.pid) 2>/dev/null") == 0)
			   or sys.call("pidof /usr/bin/tvgate/TVGate >/dev/null") == 0,
		enabled = (
			sys.call("iptables -L | grep -q tvgate") == 0 or
			uci:get("tvgate", "tvgate", "enabled") == "1"
		),
		binary_exists = nixio.fs.access("/usr/bin/tvgate/TVGate"),
		port = port
	}

	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end

-- =====================
-- download binary
-- =====================
function act_download()
	local sys = require "luci.sys"

	local rc = sys.call("/usr/bin/tvgate-download.sh >/tmp/tvgate-download.log 2>&1")
	local ok = (rc == 0)

	local log = "Log file not found"
	if nixio.fs.access("/tmp/tvgate-download.log") then
		log = sys.exec("cat /tmp/tvgate-download.log") or log
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		result = ok,
		exit_code = rc,
		log = log
	})

	sys.call("rm -f /tmp/tvgate-download.log")
end

-- =====================
-- detect arch
-- =====================
function act_detect_arch()
	local sys = require "luci.sys"
	local arch = sys.exec("uname -m"):gsub("%s+", "")

	local map = {
		x86_64  = "amd64",
		aarch64 = "arm64",
		armv7l  = "armv7",
		mips    = "mips",
		mipsel  = "mipsle",
		mipsle  = "mipsle"
	}

	local detected = map[arch] or "amd64"

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		arch = arch,
		detected_arch = detected,
		default_url =
			"https://github.com/qist/tvgate/releases/latest/download/TVGate-linux-"
			.. detected .. ".zip"
	})
end

-- =====================
-- read tvgate config.yaml
-- =====================
function act_tvgate_config()
	local path = "/etc/tvgate/config.yaml"

	if not nixio.fs.access(path) then
		luci.http.prepare_content("application/json")
		luci.http.write_json({
			error = "Config file not found: " .. path
		})
		return
	end

	local f = io.open(path, "r")
	if not f then
		luci.http.prepare_content("application/json")
		luci.http.write_json({
			error = "Failed to open config file"
		})
		return
	end

	local content = f:read("*all")
	f:close()

	local data = parse_tvgate_config(content)

	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

-- =====================
-- improved yaml parser
-- =====================
function parse_tvgate_config(content)
	local cfg = {
		web_path = "/web/",
		monitor_path = "/status",
		error = nil
	}

	if not content or content == "" then
		cfg.error = "Empty config content"
		return cfg
	end

	-- 使用更精确的正则表达式匹配
	local server_section = false
	local web_section = false
	local monitor_section = false

	for line in content:gmatch("[^\r\n]+") do
		-- 去除注释和空白
		local clean_line = line:gsub("#.*$", "")
		clean_line = clean_line:gsub("^%s+", ""):gsub("%s+$", "")
		
		if clean_line == "server:" then
			server_section = true
		elseif clean_line == "monitor:" then
			monitor_section = true
			web_section = false
			server_section = false
		elseif clean_line == "web:" then
			web_section = true
			monitor_section = false
			server_section = false
		elseif clean_line:match("^%w") and not clean_line:match(":.*%d") then
			-- 如果遇到新的顶级配置项，重置子节标志
			web_section = false
			monitor_section = false
			server_section = false
		elseif clean_line ~= "" then
			-- 在web节中查找path
			if web_section then
				local web_path = clean_line:match("^%s*path:%s*[\"']?([^\"'^%s]+)[\"']?")
				if web_path then
					cfg.web_path = web_path
				end
			-- 在monitor节中查找path
			elseif monitor_section then
				local monitor_path = clean_line:match("^%s*path:%s*[\"']?([^\"'^%s]+)[\"']?")
				if monitor_path then
					cfg.monitor_path = monitor_path
				end
			end
		end
	end

	return cfg
end