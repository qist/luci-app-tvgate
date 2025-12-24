
module("luci.controller.tvgate", package.seeall)

local ok_t, tmpl = pcall(require, "luci.template")
local Template = ok_t and tmpl.Template or (function() local ok_v, view = pcall(require, "luci.view"); if ok_v then return view.Template end end)()
local ok_fs, fs_mod = pcall(require, "nixio.fs")
if not ok_fs then ok_fs, fs_mod = pcall(require, "luci.fs") end
local fs = fs_mod

function index()
	local i18n = require "luci.i18n"
	if not fs or not fs.access("/etc/config/tvgate") then
		return
	end
 

	entry(
		{"admin", "services", "tvgate"},
		alias("admin", "services", "tvgate", "config"),
		i18n.translate("TVGate"),
		30
	).dependent = true

	entry(
		{"admin", "services", "tvgate", "config"},
		cbi("tvgate"),
		i18n.translate("Configuration"),
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
	
	entry({"admin", "services", "tvgate", "web_config"}, Template and Template("tvgate/web_config") or template("tvgate/web_config"), i18n.translate("Web 配置"), 20).leaf = true
	
	entry({"admin", "services", "tvgate", "web"}, call("act_web_config"), nil).leaf = true

end

-- =====================
-- web config API
-- =====================
function act_web_config()
	local i18n = require "luci.i18n"
	local http = require "luci.http"
	local yaml_path = "/etc/tvgate/config.yaml"
	local method = http.getenv("REQUEST_METHOD")

	if method == "GET" then
		local cfg = {
			enabled = "true",
			username = "admin",
			password = "admin",
			path = "/web/",
			monitor_path = "/status",
			port = "8888",
			log_enabled = "true",
			log_file = "",
			log_maxsize = "10",
			log_maxbackups = "10",
			log_maxage = "28",
			log_compress = "false"
		}

		if fs and fs.access(yaml_path) then
			local content = fs.readfile(yaml_path)
			if content then
				local section
				for line in content:gmatch("[^\r\n]+") do
					local clean = line:gsub("#.*$", "")
					local s = clean:match("^%s*(%w+):%s*$")
					if s then
						section = s
					else
						local k, v = clean:match("^%s*([%w_]+)%s*:%s*\"?([^\"\n]+)\"?")
						if k and v then
							if section == "web" then
								cfg[k] = v
							elseif section == "server" and k == "port" then
								cfg.port = v
							elseif section == "monitor" and k == "path" then
								cfg.monitor_path = v
							elseif section == "log" then
								if k == "enabled" then
									cfg.log_enabled = v
								elseif k == "file" then
									cfg.log_file = v
								elseif k == "maxsize" then
									cfg.log_maxsize = v
								elseif k == "maxbackups" then
									cfg.log_maxbackups = v
								elseif k == "maxage" then
									cfg.log_maxage = v
								elseif k == "compress" then
									cfg.log_compress = v
								end
							end
						end
					end
				end
			end
		end

		local function to_bool(s)
			return (s == "1" or s == "true" or s == "yes" or s == "on")
		end
		local enabled_bool = to_bool(cfg.enabled)
		local log_enabled_bool = to_bool(cfg.log_enabled)
		local log_compress_bool = to_bool(cfg.log_compress)
		http.prepare_content("application/json")
		http.write_json({
			enabled = enabled_bool,
			username = cfg.username,
			password = cfg.password,
			path = cfg.path,
			monitor_path = cfg.monitor_path,
			port = cfg.port or "8888",
			log_enabled = log_enabled_bool,
			log_file = cfg.log_file,
			log_maxsize = cfg.log_maxsize,
			log_maxbackups = cfg.log_maxbackups,
			log_maxage = cfg.log_maxage,
			log_compress = log_compress_bool
		})
		return
	end

	-- ================= POST =================

	if method == "POST" then
		local d = {
			enabled = http.formvalue("enabled") or "true",
			username = http.formvalue("username") or "admin",
			password = http.formvalue("password") or "admin",
			path = http.formvalue("path") or "/web/",
			monitor_path = http.formvalue("monitor_path") or "/status",
			port = http.formvalue("port") or "8888",
			log_enabled = http.formvalue("log_enabled") or nil,
			log_file = http.formvalue("log_file") or nil,
			log_maxsize = http.formvalue("log_maxsize") or nil,
			log_maxbackups = http.formvalue("log_maxbackups") or nil,
			log_maxage = http.formvalue("log_maxage") or nil,
			log_compress = http.formvalue("log_compress") or nil
		}
		local function normalize_bool(s)
			if not s then return nil end
			s = tostring(s):lower()
			if s == "true" or s == "1" or s == "on" or s == "yes" then return "true" end
			if s == "false" or s == "0" or s == "off" or s == "no" then return "false" end
			return s
		end
		d.log_enabled = normalize_bool(d.log_enabled)
		d.log_compress = normalize_bool(d.log_compress)

		if not (fs and fs.access(yaml_path)) then
			http.status(500, "config.yaml not found")
			return
		end
		
		local content = (fs and fs.readfile(yaml_path)) or ""
		local out = {}
		local current_section = nil
		local web_found_enabled = false
		local web_found_username = false
		local web_found_password = false
		local web_found_path = false
		local server_found_port = false
		local monitor_found_path = false
		local log_found_enabled = false
		local log_found_file = false
		local log_found_maxsize = false
		local log_found_maxbackups = false
		local log_found_maxage = false
		local log_found_compress = false
		
		for line in content:gmatch("[^\r\n]+") do
			local raw = line
			local clean = line:gsub("#.*$", "")
			local s = clean:match("^%s*(%w+):%s*$")
			
			if s then
				if current_section == "web" then
					if not web_found_enabled then table.insert(out, "  enabled: " .. d.enabled) end
					if not web_found_username then table.insert(out, "  username: " .. d.username) end
					if not web_found_password then table.insert(out, "  password: " .. d.password) end
					if not web_found_path then table.insert(out, "  path: " .. d.path) end
				elseif current_section == "server" then
					if not server_found_port then table.insert(out, "  port: " .. d.port) end
				elseif current_section == "monitor" then
					if not monitor_found_path then table.insert(out, "  path: " .. d.monitor_path) end
				elseif current_section == "log" then
					if d.log_enabled and not log_found_enabled then table.insert(out, "  enabled: " .. d.log_enabled) end
					if d.log_file and not log_found_file then table.insert(out, "  file: " .. d.log_file) end
					if d.log_maxsize and not log_found_maxsize then table.insert(out, "  maxsize: " .. d.log_maxsize) end
					if d.log_maxbackups and not log_found_maxbackups then table.insert(out, "  maxbackups: " .. d.log_maxbackups) end
					if d.log_maxage and not log_found_maxage then table.insert(out, "  maxage: " .. d.log_maxage) end
					if d.log_compress and not log_found_compress then table.insert(out, "  compress: " .. d.log_compress) end
				end
				current_section = s
				web_found_enabled, web_found_username, web_found_password, web_found_path = false, false, false, false
				server_found_port = false
				monitor_found_path = false
				log_found_enabled, log_found_file, log_found_maxsize, log_found_maxbackups, log_found_maxage, log_found_compress = false, false, false, false, false, false
				table.insert(out, raw)
			else
				if current_section == "web" then
					if clean:find("enabled:%s*") then
						table.insert(out, raw:gsub("enabled:%s*[^#]*", "enabled: " .. d.enabled))
						web_found_enabled = true
					elseif clean:find("username:%s*") then
						table.insert(out, raw:gsub("username:%s*[^#]*", "username: " .. d.username))
						web_found_username = true
					elseif clean:find("password:%s*") then
						table.insert(out, raw:gsub("password:%s*[^#]*", "password: " .. d.password))
						web_found_password = true
					elseif clean:find("path:%s*") then
						table.insert(out, raw:gsub("path:%s*[^#]*", "path: " .. d.path))
						web_found_path = true
					else
						table.insert(out, raw)
					end
				elseif current_section == "server" then
					if clean:find("port:%s*") then
						table.insert(out, raw:gsub("port:%s*[^#]*", "port: " .. d.port))
						server_found_port = true
					else
						table.insert(out, raw)
					end
				elseif current_section == "monitor" then
					if clean:find("path:%s*") then
						table.insert(out, raw:gsub("path:%s*[^#]*", "path: " .. d.monitor_path))
						monitor_found_path = true
					else
						table.insert(out, raw)
					end
				elseif current_section == "log" then
					if d.log_enabled and clean:find("enabled:%s*") then
						table.insert(out, raw:gsub("enabled:%s*[^#]*", "enabled: " .. d.log_enabled))
						log_found_enabled = true
					elseif d.log_file and clean:find("file:%s*") then
						table.insert(out, raw:gsub("file:%s*[^#]*", "file: " .. d.log_file))
						log_found_file = true
					elseif d.log_maxsize and clean:find("maxsize:%s*") then
						table.insert(out, raw:gsub("maxsize:%s*[^#]*", "maxsize: " .. d.log_maxsize))
						log_found_maxsize = true
					elseif d.log_maxbackups and clean:find("maxbackups:%s*") then
						table.insert(out, raw:gsub("maxbackups:%s*[^#]*", "maxbackups: " .. d.log_maxbackups))
						log_found_maxbackups = true
					elseif d.log_maxage and clean:find("maxage:%s*") then
						table.insert(out, raw:gsub("maxage:%s*[^#]*", "maxage: " .. d.log_maxage))
						log_found_maxage = true
					elseif d.log_compress and clean:find("compress:%s*") then
						table.insert(out, raw:gsub("compress:%s*[^#]*", "compress: " .. d.log_compress))
						log_found_compress = true
					else
						table.insert(out, raw)
					end
				else
					table.insert(out, raw)
				end
			end
		end
		
		if current_section == "web" then
			if not web_found_enabled then table.insert(out, "  enabled: " .. d.enabled) end
			if not web_found_username then table.insert(out, "  username: " .. d.username) end
			if not web_found_password then table.insert(out, "  password: " .. d.password) end
			if not web_found_path then table.insert(out, "  path: " .. d.path) end
		elseif current_section == "server" then
			if not server_found_port then table.insert(out, "  port: " .. d.port) end
		elseif current_section == "monitor" then
			if not monitor_found_path then table.insert(out, "  path: " .. d.monitor_path) end
		elseif current_section == "log" then
			if d.log_enabled and not log_found_enabled then table.insert(out, "  enabled: " .. d.log_enabled) end
			if d.log_file and not log_found_file then table.insert(out, "  file: " .. d.log_file) end
			if d.log_maxsize and not log_found_maxsize then table.insert(out, "  maxsize: " .. d.log_maxsize) end
			if d.log_maxbackups and not log_found_maxbackups then table.insert(out, "  maxbackups: " .. d.log_maxbackups) end
			if d.log_maxage and not log_found_maxage then table.insert(out, "  maxage: " .. d.log_maxage) end
			if d.log_compress and not log_found_compress then table.insert(out, "  compress: " .. d.log_compress) end
		end

		fs.writefile(yaml_path, table.concat(out, "\n"))

		local sys = require "luci.sys"
		sys.call("/etc/init.d/tvgate restart >/dev/null 2>&1")

		http.prepare_content("application/json")
		http.write_json({ result = true })
		return
	end

	http.status(405, "Method Not Allowed")
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
	
	if fs and fs.access(yaml_config_path) then
		local f = io.open(yaml_config_path, "r")
		if f then
			local content = f:read("*all")
			f:close()
			
			local current_section = nil
			for line in content:gmatch("[^\r\n]+") do
				local clean = line:gsub("#.*$", "")
				local s = clean:match("^%s*(%w+):%s*$")
				if s then
					current_section = s
				elseif current_section == "server" then
					local p = clean:match("^%s*port:%s*(%d+)")
					if p then
						port = p
						break
					end
				end
			end
		end
	end

	-- 检测服务运行状态，兼容OpenWrt和ImmortalWrt
	local running = false
	if fs and fs.access("/var/run/tvgate.pid") then
		-- 尝试使用pid文件检测
		local pid = sys.exec("cat /var/run/tvgate.pid"):match("%d+")
		if pid and pid ~= "" then
			running = (sys.call("kill -0 " .. pid .. " 2>/dev/null") == 0)
		end
	end
	
	-- 如果pid文件方式失败，使用ps命令作为备选方案
	if not running then
		running = (sys.call("ps | grep -v grep | grep -q '[/]/TVGate'") == 0)
	end

	local status = {
		running = running,
		enabled = (
			sys.call("iptables -L | grep -q tvgate") == 0 or
			uci:get("tvgate", "tvgate", "enabled") == "1"
		),
		binary_exists = (fs and fs.access("/usr/bin/tvgate/TVGate")) or false,
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
	if fs and fs.access("/tmp/tvgate-download.log") then
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

	if not (fs and fs.access(path)) then
		luci.http.prepare_content("application/json")
		luci.http.write_json({
			web_path = "/web/",
			monitor_path = "/status",
			port = "8888",
			username = "admin",
			password = "admin"
		})
		return
	end

	local f = io.open(path, "r")
	if not f then
		luci.http.prepare_content("application/json")
		luci.http.write_json({
			web_path = "/web/",
			monitor_path = "/status",
			port = "8888",
			username = "admin",
			password = "admin"
		})
		return
	end

	local content = f:read("*all")
	f:close()

	-- 手动解析YAML内容，不依赖yaml库
	local web_path = "/web/"
	local monitor_path = "/status"
	local port = "8888"
	local username = "admin"
	local password = "admin"
	local log_enabled = "true"
	local log_file = ""
	local log_maxsize = "10"
	local log_maxbackups = "10"
	local log_maxage = "28"
	local log_compress = "false"
	
	-- 解析配置文件
	local lines = {}
	for line in content:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	
	local current_section = nil
	for i, full_line in ipairs(lines) do
		-- 去除注释并清理行首空格
		local line = full_line:gsub("#.*$", ""):gsub("^%s*", "")
		
		-- 检查是否有冒号，且不在引号内
		if line ~= "" then
			-- 检查是否是新的配置节
			local section_match = line:match("^(%w+):%s*$")
			if section_match then
				current_section = section_match
			else
				-- 解析键值对
				-- 匹配 "key: value" 格式，支持带引号的值
				local key, value = line:match("^([%w_]+)%s*:%s*[\"'\"']?([^\"'\"']*)[\"'\"']?%s*$")
				if key and value then
					if current_section == "web" then
						if key == "path" then
							web_path = value
						elseif key == "username" then
							username = value
						elseif key == "password" then
							password = value
						end
					elseif current_section == "server" and key == "port" then
						port = value
					elseif current_section == "monitor" and key == "path" then
						monitor_path = value
					elseif current_section == "log" then
						if key == "enabled" then
							log_enabled = value
						elseif key == "file" then
							log_file = value
						elseif key == "maxsize" then
							log_maxsize = value
						elseif key == "maxbackups" then
							log_maxbackups = value
						elseif key == "maxage" then
							log_maxage = value
						elseif key == "compress" then
							log_compress = value
						end
					end
				end
			end
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		web_path = web_path,
		monitor_path = monitor_path,
		port = port,
		username = username,
		password = password,
		log_enabled = log_enabled,
		log_file = log_file,
		log_maxsize = log_maxsize,
		log_maxbackups = log_maxbackups,
		log_maxage = log_maxage,
		log_compress = log_compress
	})
end
