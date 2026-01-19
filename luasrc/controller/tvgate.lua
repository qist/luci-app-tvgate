
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
	local config_exists = true -- 默认认为配置文件存在，避免误触发

	-- 尝试使用nixio.fs检查文件
	local ok_nixio, nixio_fs = pcall(require, "nixio.fs")
	if ok_nixio then
		config_exists = nixio_fs.access(tvgate_config_path)
	else
		-- 尝试使用luci.fs检查文件
		local ok_luci, luci_fs = pcall(require, "luci.fs")
		if ok_luci then
			config_exists = luci_fs.access(tvgate_config_path)
		end
	end

	-- 只有在配置文件不存在时才创建
	if not config_exists then
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

	-- 使用 template 方式定义 web_config 页面路由
	local ok, view = pcall(require, "luci.view.tvgate.web_config")
	if ok then
		entry({"admin", "services", "tvgate", "web_config"}, template("tvgate/web_config"), i18n.translate("TVGate 配置"), 20).leaf = true
	else
		entry({"admin", "services", "tvgate", "web_config"}, call("display_web_config"), i18n.translate("TVGate 配置"), 20).leaf = true
	end
	
	-- 单独定义 API 接口路由
	entry({"admin", "services", "tvgate", "web"}, call("act_web_config"), nil).leaf = true

end

function display_web_config()
	local t = require "luci.template"
	t.render("tvgate/web_config")
end

-- =====================
-- web config API
-- =====================
function act_web_config()
	local i18n = require "luci.i18n"
	local http = require "luci.http"
	local sys  = require "luci.sys"
	
	-- 获取请求方法，支持_method参数模拟POST
	local method = http.getenv("REQUEST_METHOD") or "GET"
	local override_method = http.formvalue("_method")
	if override_method then
		method = override_method
	end
	local yaml_path = "/etc/tvgate/config.yaml"

	-- ================= GET =================
	if method == "GET" then
		if not (fs and fs.access(yaml_path)) then
			http.status(404, "config.yaml not found")
			return
		end
		
		-- 读取YAML配置文件
		local yaml_content = fs.readfile(yaml_path)
		if not yaml_content then
			http.status(404, "Cannot read config.yaml")
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
						-- 清理路径值，移除可能的额外空格和转义字符
						path = value and value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "") or "/web/"
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
						-- 清理端口值，移除可能的额外空格
						port = value and value:gsub("^%s+", ""):gsub("%s+$", "") or "8888"
					end
				elseif current_section == "monitor" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
					if key == "path" then
						-- 清理监控路径值，移除可能的额外空格和转义字符
						monitor_path = value and value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "") or "/status"
					end
				elseif current_section == "log" then
					local key, value = clean:match("^([%w_]+)%s*:%s*[\"']?([^\"']*)[\"']?")
					if key == "enabled" then
						log_enabled = value
					elseif key == "file" then
						-- 清理日志文件路径值，移除可能的额外空格
						log_file = value and value:gsub("^%s+", ""):gsub("%s+$", "") or ""
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
		local enabled_bool = to_bool(enabled)
		local log_enabled_bool = to_bool(log_enabled)
		local log_compress_bool = to_bool(log_compress)
		http.prepare_content("application/json")
		http.write_json({
			enabled = enabled_bool,
			username = username,
			password = password,
			path = path,
			monitor_path = monitor_path,
			port = port or "8888",
			log_enabled = log_enabled_bool,
			log_file = log_file,
			log_maxsize = log_maxsize,
			log_maxbackups = log_maxbackups,
			log_maxage = log_maxage,
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
		
		-- 使用shell脚本更新YAML配置
		-- 对参数进行安全转义，防止命令注入
		local function shell_escape(s)
			if not s then return "nil" end
			return "'" .. s:gsub("'", "'\"'\"'") .. "'"
		end
		
		local cmd = string.format("/usr/bin/tvgate-update-yaml.sh --web-path %s --username %s --password %s --port %s --monitor-path %s",
			shell_escape(d.path),
			shell_escape(d.username),
			shell_escape(d.password),
			shell_escape(d.port),
			shell_escape(d.monitor_path)
		)
		
		if d.log_enabled then cmd = cmd .. string.format(" --log-enabled %s", shell_escape(d.log_enabled)) end
		if d.log_file then cmd = cmd .. string.format(" --log-file %s", shell_escape(d.log_file)) end
		if d.log_maxsize then cmd = cmd .. string.format(" --log-maxsize %s", shell_escape(d.log_maxsize)) end
		if d.log_maxbackups then cmd = cmd .. string.format(" --log-maxbackups %s", shell_escape(d.log_maxbackups)) end
		if d.log_maxage then cmd = cmd .. string.format(" --log-maxage %s", shell_escape(d.log_maxage)) end
		if d.log_compress then cmd = cmd .. string.format(" --log-compress %s", shell_escape(d.log_compress)) end
		
		-- 执行shell脚本更新配置
		local result = sys.exec(cmd)
		
		-- 重启服务使配置生效
		sys.exec("/etc/init.d/tvgate reload >/dev/null 2>&1 &")
		
		-- 返回成功响应
		http.prepare_content("application/json")
		http.write_json({ 
			success = true,
			message = "Configuration updated successfully",
			result = result or "ok"
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

    -- 使用文件顶部已初始化的 fs（nixio.fs / luci.fs 兼容）
    local _fs = fs

    -- ===== 读取端口（稳妥版）=====
    local port = "8888"
    local yaml = "/etc/tvgate/config.yaml"

    if _fs and _fs.access(yaml) then
        for line in io.lines(yaml) do
            local p = line:match("^%s*port:%s*(%d+)")
            if p then
                port = p
                break
            end
        end
    end

    -- ===== 进程检测（唯一可信来源）=====
    local running = (sys.call("pidof /usr/bin/tvgate/TVGate >/dev/null") == 0)

    local status = {
        running = running,
        enabled = (uci:get("tvgate", "tvgate", "enabled") == "1"),
        binary_exists = (_fs and _fs.access("/usr/bin/tvgate/TVGate")) or false,
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

	-- 下载成功后重启服务
	if ok then
		sys.exec("/etc/init.d/tvgate reload >/dev/null 2>&1 &")
	end

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
		i686    = "386",
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
			password = "admin",
			log_enabled = false,
			log_file = "",
			log_maxsize = "10",
			log_maxbackups = "10",
			log_maxage = "28",
			log_compress = false
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
			password = "admin",
			log_enabled = false,
			log_file = "",
			log_maxsize = "10",
			log_maxbackups = "10",
			log_maxage = "28",
			log_compress = false
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

	local function to_bool(s)
		return (s == "1" or s == "true" or s == "yes" or s == "on")
	end
	local log_enabled_bool = to_bool(log_enabled)
	local log_compress_bool = to_bool(log_compress)

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		web_path = web_path,
		monitor_path = monitor_path,
		port = port,
		username = username,
		password = password,
		log_enabled = log_enabled_bool,
		log_file = log_file,
		log_maxsize = log_maxsize,
		log_maxbackups = log_maxbackups,
		log_maxage = log_maxage,
		log_compress = log_compress_bool
	})
end
