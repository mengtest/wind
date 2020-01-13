local skynet = require "skynet"
local socket = require "skynet.socket"
local cjson = require "cjson"
local db = require "wind.mongo"

local WATCHDOG, GATE, client_fd
local CMD = {}
local my_id

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
	return {ok = ok}
end
-----------------------------------------------
local server

local function try_handle(cmd, ...)
    local h = server[cmd]
    if h then
        h(...)
    end
end

local agent = {}

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

local CMD = {}

function CMD.wd_disconnect(fd)
    if fd == client_fd then
        try_handle("disconnect")
    else
        skynet.error("disconnect fd:%d, current fd:%d", fd, client_fd)
    end
end

function CMD.wd_reconnect(fd, addr)
    client_fd = fd
    try_handle("recnnect", addr)
	skynet.call(GATE, "lua", "forward", fd)
end

function CMD.wd_start(conf)
	local fd = conf.client
	GATE = conf.gate
	WATCHDOG = conf.watchdog
    client_fd = fd
    my_id = conf.id
    try_handle("start", my_id)
	skynet.call(GATE, "lua", "forward", fd)
end

-- call by watchdog
function CMD.wd_exit()
    try_handle("exit")
	skynet.exit()
end

-- agent call watchdog logout
-- watchdog send agent exit 
function agent.logout()
	skynet.call(WATCHDOG, "lua", "logout", my_id)
end


function agent.start(_server)
    server = _server

    local command_handler = assert(server.command_handler)

    skynet.start(function()
        try_handle("init")
        skynet.dispatch("lua", function(session, _, command, ...)
            local f = CMD[command] or command_handler
            if session == 0 then
                f(source, ...)
            else
                skynet.ret(skynet.pack(f(source, ...)))
            end
        end)
    end)
end

return agent