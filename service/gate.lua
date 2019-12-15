local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local cjson = require "cjson"

local function unpack_message(msg)
    local data = cjson.decode(msg)
    local cmd = assert(data[1])
    local args = data[2]
    if args then
        assert(type(args) == "table")
    end
    return cmd, args
end


local handle = {}
local MODE = ...

if MODE == "agent" then
    
    local client = {}
    local request = {}

    function request:login()
        return {ok = true}
    end

    function request:handshake()
        return {ok = true}
    end

    function handle.connect(id)
        client[id] = {
            connected = true,
            logined = false
        }
        print("ws connect from: " .. tostring(id))
    end

    function handle.message(id, msg)
        print(id, msg)
        local function close_client(errmsg)
            errmsg = errmsg or "invalid client"
            client[id] = nil
            skynet.error(errmsg)
            websocket.write(id, errmsg)
            websocket.close(id)
        end

        local c = client[id]
        if c.agent then
            local r = skynet.call(c.agent, "lua", "client", msg)
            if r then
                websocket.write(id, r)
            end
        else
            local ok, cmd, args = pcall(unpack_message, msg)
            if not ok then
                return close_client(cmd)
            end

            local f = request[cmd]
            if not f then
                return close_client("invalid cmd:"..tostring(cmd))
            end

            local ok, r = pcall(f, args)
            if not ok then
                return close_client(r)
            end

            return websocket.write(id, cjson.encode(r))
        end
    end

    function handle.close(id, code, reason)
        local c = client[id]
        if c then
            c.connected = false
        end
        print("ws close from: " .. tostring(id), code, reason)
    end

    function handle.error(id)
        print("ws error from: " .. tostring(id))
    end

    skynet.start(function ()
        skynet.dispatch("lua", function (_,_, id, protocol, addr)
            local ok, err = websocket.accept(id, handle, protocol, addr)
            if not ok then
                print(err)
            end
        end)
    end)

else
    skynet.start(function ()
        local agent = {}
        for i= 1, skynet.getenv "thread" do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent")
        end
        local balance = 1
        local protocol = "ws"
        local id = socket.listen("0.0.0.0", 9013)
        skynet.error(string.format("Listen websocket port 9013 protocol:%s", protocol))
        socket.start(id, function(id, addr)
            print(string.format("accept client socket_id: %s addr:%s", id, addr))
            skynet.send(agent[balance], "lua", id, protocol, addr)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)
end