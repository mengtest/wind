local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server_conf = require "config.server"

skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server_conf.name.." start")
	skynet.error("=============================================")

	snax.newservice("loginserver", {
		port = 9005,
		worker = "loginworker"
	})

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	
	skynet.exit()
end)
