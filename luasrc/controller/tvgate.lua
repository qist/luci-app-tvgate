
module("luci.controller.tvgate", package.seeall)

local ok_t, tmpl = pcall(require, "luci.template")
local Template = ok_t and tmpl.Template or (function() local ok_v, view = pcall(require, "luci.view"); if ok_v then return view.Template end end)()
local ok_fs, fs_mod = pcall(require, "nixio.fs")
if not ok_fs then ok_fs, fs_mod = pcall(require, "luci.fs") end
local fs = fs_mod

function index()
	local i18n = require "luci.i18n"
	local uci = require "luci.model.uci".cursor()
	
	-- 检查并创建UCI配置文件（如果不存在）
	local tvgate_config_path = "/etc/config/tvgate"
	if not fs or not fs.access(tvgate_config_path) then
		-- 使用luci.sys来创建配置文件
		local sys = require "luci.sys"
		sys.call("touch /etc/config/tvgate >/dev/null 2>&1")
		-- 设置默认值
		uci:set("tvgate", "tvgate", "enabled", "0")
		uci:commit("tvgate")
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
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	
	local method = http.getenv("REQUEST_METHOD")
	local yaml_path = "/etc/tvgate/config.yaml"

	-- 如果配置文件不存在，创建默认配置
	if not fs.access(yaml_path) then
		sys.call("mkdir -p /etc/tvgate >/dev/null 2>&1")
		local default_config = [[server:
  #监听端口
  port: 8888
# 监控配置
monitor:
  path: "/status" # 状态信息

# 配置文件编辑接口
web:
  enabled: true
  username: admin
  password: admin
  path: /web/ # 自定义路径
]]
		fs.writefile(yaml_path, default_config)
	end

	-- ================= GET =================
	if method == "GET" then
		-- 读取YAML配置文件
		local yaml_content = fs.readfile(yaml_path)
		if not yaml_content then
			http.status(500, "Cannot read config.yaml")
			return
		end

		-- 解析YAML获取当前配置
		local port = "8888"
		local path = "/web/"
		local username = "admin"
		local password = "admin"
		local monitor_path = "/status"
		local enabled = "true"
		local log_enabled = "true"
		local log_file = ""
		local log_maxsize = "10"
		local log_maxbackups = "10"
		local log_maxage = "28"
		local log_compress = "false"
		
		local current_section = nil
		for line in yaml_content:gmatch("[^\r\n]+") do
			local clean = line:gsub("#.*$", ""):gsub("^%s*", "")
			local s = clean:match("^(%w+):%s*$")
			if s then
				current_section = s
			else
				if current_section == "web" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
					if key == "path" then
						path = value
					elseif key == "username" then
						username = value
					elseif key == "password" then
						password = value
					elseif key == "enabled" then
						enabled = value
					end
				elseif current_section == "server" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
					if key == "port" then
						port = value
					end
				elseif current_section == "monitor" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
					if key == "path" then
						monitor_path = value
					end
				elseif current_section == "log" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
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
		
		-- 构建新的YAML配置内容
		local new_config = {}
		local added_sections = {}

		-- 读取现有配置作为基础
		local existing_content = fs.readfile(yaml_path) or ""
		local lines = {}
		for line in existing_content:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end

		-- 先标记已有的section
		for _, line in ipairs(lines) do
			local clean = line:gsub("#.*$", "")
			local section = clean:match("^%s*(%w+):%s*$")
			if section then
				added_sections[section] = true
			end
		end

		-- 构建新的配置内容
		local output_lines = {}

		-- 处理已有行，更新相关部分
		local in_web_section = false
		local in_server_section = false
		local in_monitor_section = false
		local in_log_section = false
		local web_updated = false
		local server_updated = false
		local monitor_updated = false
		local log_updated = false

		for _, line in ipairs(lines) do
			local clean = line:gsub("#.*$", "")
			local section = clean:match("^%s*(%w+):%s*$")
			
			if section then
				in_web_section = (section == "web")
				in_server_section = (section == "server")
				in_monitor_section = (section == "monitor")
				in_log_section = (section == "log")
				table.insert(output_lines, line)
			elseif in_web_section then
				local key = clean:match("^%s*([%w_]+)%s*:.*$")
				if key == "path" then
					table.insert(output_lines, string.format("  path: %s", d.path))
					web_updated = true
				elseif key == "username" then
					table.insert(output_lines, string.format("  username: %s", d.username))
					web_updated = true
				elseif key == "password" then
					table.insert(output_lines, string.format("  password: %s", d.password))
					web_updated = true
				elseif key == "enabled" then
					table.insert(output_lines, string.format("  enabled: %s", d.enabled))
					web_updated = true
				else
					table.insert(output_lines, line)
				end
			elseif in_server_section then
				local key = clean:match("^%s*([%w_]+)%s*:.*$")
				if key == "port" then
					table.insert(output_lines, string.format("  port: %s", d.port))
					server_updated = true
				else
					table.insert(output_lines, line)
				end
			elseif in_monitor_section then
				local key = clean:match("^%s*([%w_]+)%s*:.*$")
				if key == "path" then
					table.insert(output_lines, string.format("  path: %s", d.monitor_path))
					monitor_updated = true
				else
					table.insert(output_lines, line)
				end
			elseif in_log_section then
				local updated = false
				if d.log_enabled ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "enabled" then
						table.insert(output_lines, string.format("  enabled: %s", d.log_enabled))
						updated = true
						log_updated = true
					end
				end
				if d.log_file ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "file" then
						table.insert(output_lines, string.format("  file: %s", d.log_file))
						updated = true
						log_updated = true
					end
				end
				if d.log_maxsize ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "maxsize" then
						table.insert(output_lines, string.format("  maxsize: %s", d.log_maxsize))
						updated = true
						log_updated = true
					end
				end
				if d.log_maxbackups ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "maxbackups" then
						table.insert(output_lines, string.format("  maxbackups: %s", d.log_maxbackups))
						updated = true
						log_updated = true
					end
				end
				if d.log_maxage ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "maxage" then
						table.insert(output_lines, string.format("  maxage: %s", d.log_maxage))
						updated = true
						log_updated = true
					end
				end
				if d.log_compress ~= nil then
					local key = clean:match("^%s*([%w_]+)%s*:.*$")
					if key == "compress" then
						table.insert(output_lines, string.format("  compress: %s", d.log_compress))
						updated = true
						log_updated = true
					end
				end
				if not updated then
					table.insert(output_lines, line)
				end
			else
				table.insert(output_lines, line)
			end
		end

		-- 如果没有找到对应的section，则添加
		if not web_updated then
			if not added_sections.web then
				table.insert(output_lines, "web:")
				added_sections.web = true
			end
			table.insert(output_lines, string.format("  path: %s", d.path))
			table.insert(output_lines, string.format("  username: %s", d.username))
			table.insert(output_lines, string.format("  password: %s", d.password))
			table.insert(output_lines, string.format("  enabled: %s", d.enabled))
		end

		if not server_updated then
			if not added_sections.server then
				table.insert(output_lines, "server:")
				added_sections.server = true
			end
			table.insert(output_lines, string.format("  port: %s", d.port))
		end

		if not monitor_updated then
			if not added_sections.monitor then
				table.insert(output_lines, "monitor:")
				added_sections.monitor = true
			end
			table.insert(output_lines, string.format("  path: %s", d.monitor_path))
		end

		if (d.log_enabled ~= nil or d.log_file ~= nil or d.log_maxsize ~= nil or 
			d.log_maxbackups ~= nil or d.log_maxage ~= nil or d.log_compress ~= nil) and not log_updated then
			if not added_sections.log then
				table.insert(output_lines, "log:")
				added_sections.log = true
			end
			if d.log_enabled ~= nil then
				table.insert(output_lines, string.format("  enabled: %s", d.log_enabled))
			end
			if d.log_file ~= nil then
				table.insert(output_lines, string.format("  file: %s", d.log_file))
			end
			if d.log_maxsize ~= nil then
				table.insert(output_lines, string.format("  maxsize: %s", d.log_maxsize))
			end
			if d.log_maxbackups ~= nil then
				table.insert(output_lines, string.format("  maxbackups: %s", d.log_maxbackups))
			end
			if d.log_maxage ~= nil then
				table.insert(output_lines, string.format("  maxage: %s", d.log_maxage))
			end
			if d.log_compress ~= nil then
				table.insert(output_lines, string.format("  compress: %s", d.log_compress))
			end
		end

		-- 写入新配置
		local success = fs.writefile(yaml_path, table.concat(output_lines, "\n"))
		if not success then
			http.status(500, "Failed to write config file")
			return
		end

		-- 重启服务使配置生效
		sys.call("/etc/init.d/tvgate reload >/dev/null 2>&1 &")
		
		-- 返回成功响应
		http.prepare_content("application/json")
		http.write({ 
			success = true,
			message = "Configuration updated successfully"
		})
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
		running = (sys.call("ps | grep -v grep | grep -q 'TVGate'") == 0)
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
