local skynet = require "skynet"
local websocket = require "http.websocket"
local socketdriver = require "skynet.socketdriver"
local kvdb = require "wind.kvdb"

local token = require "wind.token"

local protocol, nodelay = ...

local connection = {}
local client = {}

local handle = {}

function handle.connect(fd)
	if nodelay then
		socketdriver.nodelay(fd)
    end
    connection[fd] = true
    print("ws connect from: " .. tostring(fd))
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    local err, id, expire_time = token.auth(header.token)
    if err then
        websocket.close(fd)
        return
    end
    local agent = kvdb.user_agent.get(id)
    if not agent or not pcall(skynet.send, agent, "lua", "reconnect", fd, protocol, addr) then
        agent = skynet.newservice("ws-agent")
        kvdb.user_agent.set(id, agent)
        skynet.send(agent, "lua", "start", id, fd, protocol, addr)
    end
    client[fd] = agent
end

function handle.message(fd, msg)
    if connection[fd] then
        local a = assert(client[fd])
        skynet.send(a, "lua", "client", msg)
    else
        skynet.error(string.format("Drop message from fd (%d) : %s", fd, msg))
    end
end

function handle.ping(id)
    print("ws ping from: " .. tostring(id) .. "\n")
end

function handle.pong(id)
    print("ws pong from: " .. tostring(id))
end

function handle.close(fd, code, reason)
    connection[fd] = nil
    print("ws close from: " .. tostring(fd), code, reason)
end

function handle.error(id)
    print("ws error from: " .. tostring(id))
end

--
-- CMD
--
local commond = {}

function commond.close_client(fd, id)
    kvdb.user_agent.set(id, nil)
    client[fd] = nil
end

function commond.accept(fd, addr)
    local ok, err = websocket.accept(fd, handle, protocol, addr)
    if not ok then
        skynet.error(err)
    else
        skynet.error("accept", fd, addr)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, _, cmd, ...)
        local f = assert(commond[cmd], cmd)
        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)