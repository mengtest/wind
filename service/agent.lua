local skynet = require "skynet"
local websocket = require "http.websocket"
local cjson = require "cjson"


local client_fd
local request = {}


function request:start_match()
	return {ok = false, msg = "you start match ...."}
end



-----------------------------------------------------
local commond = {}

function commond.client(msg)
	local data = cjson.decode(msg)
	local cmd, args = data[1], data[2] or {}
	local f = request[cmd]
	return cjson.encode(f(args))
end

function commond.start(fd, pid)
	client_fd = fd
	skynet.error("start =============================", fd, pid)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    		print("lua:", cmd, ...)
            local f = assert(commond[cmd], cmd)
            skynet.ret(skynet.pack(f(...)))
    end)
end)