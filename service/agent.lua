local skynet = require "skynet"
local websocket = require "http.websocket"
local cjson = require "cjson"

local gate

local function send_request(cmd, args)
	local msg = cjson.encode({cmd, args})
	skynet.send(gate, "lua", "send_request", msg)
end

local request = {}


function request:start_match()
	return {ok = false, msg = "you start match ...."}
end



-----------------------------------------------------
local commond = {}

function commond.client(source, msg)
	local data = cjson.decode(msg)
	local cmd, args = data[1], data[2] or {}
	local f = request[cmd]
	return cjson.encode(f(args))
end

function commond.start(source, pid)
	gate = source
	skynet.error("start =============================", gate, pid)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,source, cmd, ...)
		print("lua:", cmd, ...)
		local f = assert(commond[cmd], cmd)
		skynet.ret(skynet.pack(f(source, ...)))
    end)
end)