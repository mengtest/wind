local skynet = require "skynet"
local socket = require "skynet.socket"



local function client()
	local c = socket.udp(function(str, from)
		print("client recv", str, socket.udp_address(from))
	end)
	socket.udp_connect(c, "127.0.0.1", 9014)
	for i=1,20 do
		skynet.sleep(10)
		socket.write(c, "hello " .. i)	-- write to the address by udp_connect binding
	end
end

skynet.start(function ()
	client()
end)