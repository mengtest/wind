local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server_conf = require "config.server"
local schedule = require "schedule"
local crypt = require "skynet.crypt"
local wind = require "wind"


skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server_conf.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end

	local u = wind.find_one("user", {id = "123456"})


	table.insert(u.mails, 1, {id = 11, gold = 3333})
	table.insert(u.mails, 3, {id = 33, gold = 3333})

	table.sort(u.mails, function (a, b)
		return a.id > b.id
	end)


    snax.newservice("webserver", {
    	host = "0.0.0.0",
        port = 9005,
        worker = "web-worker"
    })

	skynet.exit()
end)
