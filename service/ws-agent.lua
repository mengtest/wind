local skynet = require "skynet"
require "skynet.queue"
local websocket = require "http.websocket"
local cjson = require "cjson"
local db = require "wind.mongo"

local lock = skynet.queue()
local client_fd, gate, me

local function send_request(cmd, args)
	local msg = cjson.encode({cmd, args})
	skynet.send(gate, "lua", "send_request", me.id, msg)
end

local request = {}

function request:self_info()
	return table.filter(me, function(k,v)
		return k ~= "_id"
	end)
end


function request:start_match()
	return {ok = false, msg = "you start match ...."}
end



-----------------------------------------------------
local commond = {}

function commond.client(source, msg)
	return lock(function()
		local data = cjson.decode(msg)
		local session, cmd, args = data[1], data[2], data[3] or {}
		local f = request[cmd]
		local r = f(args)
		return cjson.encode({session, r})	
	end)
end

function commond.reconnect(source, fd, protocol, addr)
	client_fd = fd
	websocket.forward(fd, protocol, addr)
end

function commond.start(source, id, fd, protocol, addr)
	client_fd = fd
	websocket.forward(fd, protocol, addr)
	gate = source
	me = db.user.miss_find_one({id = id})
	dump(me)
	skynet.fork(function()
		while true do 
			skynet.sleep(500)
			send_request("heartbeat", {msg = "hello client"})
		end
	end)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(commond[cmd], cmd)
		if session == 0 then
			f(source, ...)
		else
			skynet.ret(skynet.pack(f(source, ...)))
		end
    end)
end)