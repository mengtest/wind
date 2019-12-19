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
local MODE, master = ...

if MODE == "agent" then
    master = tonumber(master)

    local client = {}
    local request = {}

    function request:login(fd)
        local id = assert(self.id)
        local c = client[fd]
        c.id = id
        c.agent = skynet.newservice("agent")
        client[id] = c

        skynet.call(c.agent, "lua", "start", id)
        return {ok = true}
    end

    function request:handshake(fd)
        return {ok = true}
    end

    function handle.connect(fd)
        client[fd] = {
            connected = true,
            logined = false
        }
        skynet.send(master, "lua", "an_client_connect")
        print("ws connect from: " .. tostring(fd))
    end

    function handle.message(fd, msg)
        print(fd, msg)
        local function close_client(errmsg)
            errmsg = errmsg or "invalid client"
            client[fd] = nil
            skynet.error(errmsg)
            websocket.write(fd, errmsg)
            websocket.close(fd)
        end

        local c = client[fd]
        if c.agent then
            local session = string.unpack(">I4", msg, -4)
            msg = msg:sub(1,-5)
            local response = skynet.call(c.agent, "lua", "client", msg)
            c.msg_index = c.msg_index + 1
            response = response .. string.pack(">I4I4", session, c.msg_index)
            print("response:", response)
            websocket.write(id, response)
        else
            local ok, cmd, args = pcall(unpack_message, msg)
            if not ok then
                return close_client(cmd)
            end

            local f = request[cmd]
            if not f then
                return close_client("invalid cmd:"..tostring(cmd))
            end

            local ok, r = pcall(f, args, fd)
            if not ok then
                return close_client(r)
            end

            return websocket.write(fd, cjson.encode(r))
        end
    end

    function handle.close(fd, code, reason)
        local c = client[fd]
        if c then
            c.connected = false
        end
        skynet.send(master, "lua", "an_client_disconnect")
        print("ws close from: " .. tostring(fd), code, reason)
    end

    function handle.error(fd)
        print("ws error from: " .. tostring(fd))
    end

    local commond = {}

    function commond.send_request(pid, msg)
        local c = client[pid]
        websocket.write(c.fd, msg)
    end

    skynet.start(function ()
        skynet.dispatch("lua", function (_,_, fd, protocol, addr, ...)
            if type(fd) == "number" then
                local ok, err = websocket.accept(fd, handle, protocol, addr)
                if not ok then
                    print(err)
                end
            else
                local f = assert(commond[fd])
                skynet.ret(skynet.pack(f(protocol, addr, ...)))
            end
        end)
    end)
else
    local maxclient = 8888
    local connectedc = 0

    local commond = {}

    function commond.an_client_connect()
        connectedc = connectedc + 1
    end

    function commond.an_client_disconnect()
        connectedc = connectedc - 1
    end

    skynet.dispatch("lua", function (_,_, cmd, ...)
        local f = commond[cmd]
        f(...)
    end)
    skynet.start(function ()
        local agent = {}
        for i= 1, skynet.getenv "thread" do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent", skynet.self())
        end
        local balance = 1
        local protocol = "ws"
        local id = socket.listen("0.0.0.0", 9013)
        skynet.error(string.format("Listen websocket port 9013 protocol:%s", protocol))
        socket.start(id, function(fd, addr)
            if connectedc < maxclient then
                print(string.format("accept client socket_fd: %s addr:%s", fd, addr))
                skynet.send(agent[balance], "lua", fd, protocol, addr)
                balance = balance + 1
                if balance > #agent then
                    balance = 1
                end
            else
                socket.close(fd)
                skynet.error("num of client is max:", maxclient)
            end
        end)
    end)
end