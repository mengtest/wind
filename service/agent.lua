local skynet = require "skynet"
local socket = require "skynet.socket"
local cjson = require "cjson"
local db = require "wind.mongo"

local WATCHDOG, GATE, client_fd
local CMD = {}
local REQUEST = {}
local me

local sender = {
	index = 0,
	packs = {},
}

local function sender_send(type, ...)
	sender.index = sender.index + 1
	local pack = string.pack(">s2", cjson.encode{type, sender.index, ...})
	table.insert(sender.packs, {index = index, pack = pack})
	if #sender.packs == 256 then
		table.remove(sender.packs, 1)
	end
	socket.write(client_fd, pack)
end

function sender.send_request(name, args)
	sender_send(0, name, args)
end

function sender.send_respone(session, res)
	sender_send(1, session, res)
end

function sender.handshake(index)
	local packs_len = #sender.packs
	local sender_index = sender.index

	if index == 0 then
		if sender_index == 0 then
			return true
		else
			-- 客户端是重新登录的, 重置sender状态
			sender.index = 0
			sender.packs = {}
			return false
		end
	else
		if sender_index - index > 256 or index > sender_index then
			-- 部分信息已经丢失, 或者客户端索引错误
			sender.index = 0
			sender.packs = {}
			return false
		else
			local start_pack_index = index - sender.packs[1].index + 1
			for i=start_pack_index,packs_len do
				local pack = sender.packs[i].pack
				socket.write(client_fd, pack)
			end
			return true
		end
	end
end
-------------------------------------------------------------------------
-- REQUEST
function REQUEST:handshake()
	local ok = sender.handshake(self.msgindex)
	return {ok = ok, index = sender.index}
end

-- client call agent quit
-- agent call watchdog logout
-- watchdog send agent exit 
function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "logout", me.id)
end

function REQUEST:hello()
	return {hello = "wind"}
end

-- REQUEST
-------------------------------------------------------------------------

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function(data, sz)
		local msg = skynet.tostring(data, sz)
		msg = cjson.decode(msg)
		return msg[1], msg[2], msg[3]
	end,
	dispatch = function (fd, _, session, name, args)
		assert(fd == client_fd)
		skynet.ignoreret()
		skynet.error("msg:", session, name, args)
		local f = REQUEST[name]
		sender.send_respone(session, f(args))
	end
}

function CMD.disconnect(fd)
	skynet.error("client disconnect", fd)
end

function CMD.reconnect(fd, addr)
	skynet.error("reconnect", fd, addr)
	client_fd = fd
	skynet.call(GATE, "lua", "forward", fd)
end

function CMD.start(conf)
	dump(conf)
	local fd = conf.client
	GATE = conf.gate
	WATCHDOG = conf.watchdog
	client_fd = fd
	me = db.user.miss_find_one{id = conf.id}
	dump(me)
	skynet.call(GATE, "lua", "forward", fd)
end

-- call by watchdog
function CMD.exit()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
