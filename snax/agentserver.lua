local skynet = require "skynet"
local socket = require "skynet.socket"
local cjson = require "cjson"
local db = require "wind.mongo"

local WATCHDOG, GATE, client_fd
local my_id

-----------------------------------------------------------------
-- NET
-----------------------------------------------------------------
local msgindex = 0
local msgpacks = {}

local function send2client(type, ...)
	msgindex = msgindex + 1
	local pack = string.pack(">s2", cjson.encode{type, msgindex, ...})
	msgpacks[msgindex] = pack
	if msgindex > 256 then
		msgpacks[msgindex-256] = nil
	end
	socket.write(client_fd, pack)
end

local function send_request(name, args)
	send2client(0, name, args)
end

local function send_respone(session, res)
	send2client(1, session, res)
end

local function handshake(index)
	if index == 0 then
		if msgindex == 0 then
			return true
		else
			-- 客户端是重新登录的, 重置状态
			msgindex = 0
			msgpacks = {}
			return false
		end
	else
		if msgindex - index > 256 or index > msgindex then
			-- 部分信息已经丢失, 或者客户端索引错误
			msgindex = 0
			msgpacks = {}
			return false
		else
			for i=index+1,msgindex do
				socket.write(client_fd, msgpacks[i])
			end
			return true
		end
	end
end

-----------------------------------------------------------------
-- CLIENT REQUEST
-----------------------------------------------------------------
local REQUEST = {}

function REQUEST:handshake()
	local ok = handshake(self.msgindex)
	return {ok = ok}
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function(data, sz)
		local msg = skynet.tostring(data, sz)
		skynet.error("client:", msg)
		msg = cjson.decode(msg)
		return msg[1], msg[2], msg[3]
	end,
	dispatch = function (fd, _, session, name, args)
		assert(fd == client_fd)
		skynet.ignoreret()
		local f = REQUEST[name]
		send_respone(session, f(args))
	end
}
-----------------------------------------------------------------
-- CMD and Handle
-----------------------------------------------------------------
local handle
local CMD = {}

local function try_handle(cmd, ...)
    local h = handle[cmd]
    if h then
        h(...)
    end
end

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
    try_handle("start", my_id, conf.addr)
	skynet.call(GATE, "lua", "forward", fd)
end

-- call by watchdog
function CMD.wd_exit()
    try_handle("exit")
	skynet.exit()
end

-----------------------------------------------------------------
-- API
-----------------------------------------------------------------
local agent = {
	send_request = send_request
}

-- agent call watchdog logout
-- watchdog send agent exit 
function agent.logout()
	skynet.call(WATCHDOG, "lua", "logout", my_id)
end

function agent.start(h)
	handle = h
	
	for k,v in pairs(handle.request) do
		assert(not REQUEST[k])
		REQUEST[k] = v
	end

	if handle.command then
		for k,v in pairs(handle.command) do 
			assert(not CMD[k])
			CMD[k] = v
		end
	end

    skynet.start(function()
        try_handle("init")
        skynet.dispatch("lua", function(session, _, command, ...)
            local f = CMD[command]
            if session == 0 then
                f(source, ...)
            else
                skynet.ret(skynet.pack(f(...)))
            end
        end)
    end)
end

return agent