local skynet = require "skynet"
local socket = require "skynet.socket"

local agent = {}


skynet.start(function()
	skynet.error("lobby[udp] listen:", 9014)
	local host = socket.udp(function(str, from)
		
		-- socket.sendto(host, from, "OK " .. str)
	end , "0.0.0.0", 9014)
end)