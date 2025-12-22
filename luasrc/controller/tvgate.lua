module("luci.controller.tvgate", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/tvgate") then
		return
	end
	
	entry({"admin", "services", "tvgate"}, alias("admin", "services", "tvgate", "config"), _("TVGate"), 30).dependent = true
	entry({"admin", "services", "tvgate", "config"}, cbi("tvgate"), _("Configuration"), 10).leaf = true
	entry({"admin", "services", "tvgate", "status"}, call("act_status")).leaf = true
	entry({"admin", "services", "tvgate", "download"}, call("act_download")).leaf = true
	entry({"admin", "services", "tvgate", "restart"}, call("act_restart")).leaf = true
	entry({"admin", "services", "tvgate", "stop"}, call("act_stop")).leaf = true
	entry({"admin", "services", "tvgate", "log"}, call("act_log")).leaf = true
end

function act_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	
	local status = {
		running = sys.call("pidof TVGate >/dev/null") == 0,
		enabled = sys.call("iptables -L | grep -q \"tvgate\"") == 0 or uci:get("tvgate", "tvgate", "enabled") == "1",
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

function act_restart()
	local sys = require "luci.sys"
	
	local ret = {
		result = sys.call("/etc/init.d/tvgate restart >/tmp/tvgate-restart.log 2>&1") == 0,
		log = sys.exec("cat /tmp/tvgate-restart.log")
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(ret)
	
	-- Clean up log file
	sys.call("rm -f /tmp/tvgate-restart.log")
end

function act_stop()
	local sys = require "luci.sys"
	
	local ret = {
		result = sys.call("/etc/init.d/tvgate stop >/tmp/tvgate-stop.log 2>&1") == 0,
		log = sys.exec("cat /tmp/tvgate-stop.log")
	}
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(ret)
	
	-- Clean up log file
	sys.call("rm -f /tmp/tvgate-stop.log")
end

function act_log()
	local sys = require "luci.sys"
	
	local log_content = ""
	if sys.call("test -f /var/log/tvgate.log") == 0 then
		log_content = sys.exec("tail -n 100 /var/log/tvgate.log")
	else
		log_content = sys.exec("journalctl -u tvgate --no-pager | tail -n 100")
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json({log = log_content})
end