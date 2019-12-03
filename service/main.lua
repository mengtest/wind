local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server_conf = require "config.server"
local kvdb = require "wind.kvdb"

skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server_conf.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end

	kvdb.user.set("windy", "logined")
	kvdb.user.set("xixi", "hi xixi")


	skynet.newservice("debug_console", 9999)
	skynet.newservice("logind")
	skynet.newservice("lobby")
	skynet.newservice("game")

	
	skynet.exit()
end)
