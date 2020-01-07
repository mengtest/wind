local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local WATCHDOG, GATE, client_fd
local CMD = {}
local REQUEST = {}
local me

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

-- client call agent quit
-- agent call watchdog logout
-- watchdog send agent exit 
function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "logout", me.id)
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
	dispatch = function (fd, _, msg)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		print("msg:", msg)
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
