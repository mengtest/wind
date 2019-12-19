local skynet = require "skynet"
local web = require "snax.webserver"

local request = {}

function request:login()
	local token = 'TOKEN'..self.id
	return {token = token}
end




----------------------------------------------
local commond = {}


web {
	name = "login-master",
	host = "0.0.0.0",
	port = 9011,
	request = request,
	commond = commond
}