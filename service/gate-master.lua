local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local kvdb = require "wind.kvdb"

local slave = {}


local commond = {}

function commond.start(conf)
    local balance = 1
    local maxclient = conf.maxclient or 8888
    local host = conf.host or "0.0.0.0"
    local port = assert(conf.port)
    local protocol = conf.protocol or "ws"
    local nodelay = conf.nodelay and "nodelay"
    assert(protocol == "ws" or protocol == "wss")

    for i= 1, skynet.getenv "thread" do
        slave[i] = skynet.newservice("gate-slave", protocol, nodelay)
    end

    local id = socket.listen(host, port)
    skynet.error(string.format("Listen websocket port:%d, protocol:%s", port, protocol))
    socket.start(id, function(id, addr)
        if kvdb.gate.get("client_num") >= maxclient then
            socket.close_fd(id)
            return
        end
        print(string.format("accept client socket_id: %s addr:%s", id, addr))
        skynet.send(slave[balance], "lua", "accept", id, addr)
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
    end)
end


skynet.start(function ()
    kvdb.gate.set("client_num", 0)
    skynet.dispatch("lua", function(session, _, cmd, ...)
        local f = commond[cmd]
        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)