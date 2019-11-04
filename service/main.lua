local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server_conf = require "config.server"
local db = require "db.mongo"
local schedule = require "schedule"


skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server_conf.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
 
	dump(db.insert("user", {id = '999', nick = 'xixi'}))
	dump(db.find_one("user", {id = '123456'}))

	skynet.exit()
end)
