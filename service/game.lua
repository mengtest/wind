local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"


local user = {}
local handle = {}

function handle.connect(id)
    print("ws connect from: " .. tostring(id))
end

function handle.message(id, msg)
    websocket.write(id, msg)
end

function handle.close(id, code, reason)
    print("ws close from: " .. tostring(id), code, reason)
end

function handle.error(id)
    print("ws error from: " .. tostring(id))
end

skynet.start(function ()
    local protocol = "ws"
    local id = socket.listen("0.0.0.0", 9948)
    skynet.error(string.format("Listen websocket port 9948 protocol:%s", protocol))
    socket.start(id, function(id, addr)
        print(string.format("accept client socket_id: %s addr:%s", id, addr))
        local ok, err = websocket.accept(id, handle, protocol, addr)
        if not ok then
            print(err)
        end
    end)
end)