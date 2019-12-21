local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local token = require "wind.token"
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

    local function handshake(fd, args)
        local err, uid = token.auth(args.token)
        if err then
            return {err = err}
        else
            local c = client[fd]
            c.agent = c.agent or skynet.newservice("agent")
            skynet.call(c.agent, "lua", "start", skynet.self(), uid)
            local packs = c.cache
            c.cache = {}
            c.fd = fd
            return {cache_packs = packs}
        end
    end

    function handle.connect(fd)
        client[fd] = {
            fd = fd,
            cache = {}
        }
        skynet.send(master, "lua", "an_client_connect")
        print("ws connect from: " .. tostring(fd))
    end

    local function send2client(c, msg)
        local fd = c.fd
        if fd and websocket.write(fd, msg) then
            return true
        else
            table.insert(c.cache, msg)
            return false, #c.cache
        end
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
            local session = string.unpack(">I4I4", msg, -8)
            msg = msg:sub(1,-5)
            local response = skynet.call(c.agent, "lua", "client", msg)
            c.msg_index = c.msg_index + 1
            response = response .. string.pack(">I4I4", session, c.msg_index)
            print("response:", response)
            websocket.write(fd, response)
        else
            -- must be handshake
            local ok, cmd, args = pcall(unpack_message, msg)
            if not ok then
                return close_client(cmd)
            end

            if cmd ~= "handshake" then
                return close_client("need handshake:"..tostring(cmd))
            end

            local ok, r = pcall(handshake, fd, args)
            if not ok then
                return close_client(r)
            end

            if not websocket.write(fd, cjson.encode(r)) then
                -- handshake not done, kill out
            end
        end
    end

    function handle.close(fd, code, reason)
        local c = client[fd]
        if c then
            c.fd = nil
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