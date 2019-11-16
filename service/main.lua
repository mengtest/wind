local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server_conf = require "config.server"
local schedule = require "schedule"
local crypt = require "skynet.crypt"


skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server_conf.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end



    snax.newservice("webserver", {
    	host = "0.0.0.0",
        port = 9005,
        worker = "web-game"
    })

	skynet.exit()
end)
