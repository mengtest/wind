local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server = require "config.server"

skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console", 9999)
	skynet.newservice("admin")

	skynet.newservice("login")
	local gate = skynet.newservice("ws-gate-master")
	skynet.call(gate, "lua", "start", {
		port = 8888,
		maxclient = 8888,
		nodelay = true,
	})
	
	skynet.newservice("ws-client")

	skynet.exit()
end)
