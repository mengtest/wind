local skynet = require "skynet"
local web = require "snax.webserver"
local token = require "wind.token"

local request = {}

function request:login()
	local t = token.encode(self.id)
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