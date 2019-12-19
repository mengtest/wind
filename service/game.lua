local skynet = require "skynet"
local socket = require "skynet.socket"

local host

skynet.start(function()
	skynet.error("gate[udp] listen:", 9014)

	host = socket.udp(function(str, from)
		print("server recv", str, socket.udp_address(from))
		socket.sendto(host, from, "OK " .. str)
	end , "0.0.0.0", 9015)
end)