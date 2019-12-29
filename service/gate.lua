local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local token = require "wind.token"
local cjson = require "cjson"

print = skynet.error


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


    function handle.connect(fd)
        skynet.send(master, "lua", "an_client_connect")
        print("ws connect from: " .. tostring(fd))
    end

    local function send2client(c, msg)
        local fd = c.fd
        if fd and websocket.write(fd, msg) then
            return true
        else
            table.insert(c.packs, msg)
            return false, #c.packs
        end
    end

    function handle.handshake(fd, header, url)
        local err, uid = token.auth(header.token)
        if err then
            websocket.close(fd)
            skynet.error("handshake failed", fd)
        else
            local c = client[uid]
            if c then
                local packs = #c.packs > 0 and c.packs
                c.fd = fd
                c.packs = {}
                client[fd] = c
                websocket.write(fd, cjson.encode({packs = packs}))
            else
                local agent = skynet.newservice("agent")
                skynet.call(agent, "lua", "start", skynet.self(), uid)
                c = {
                    id = uid,
                    fd = fd,
                    agent = agent,
                    packs = {}
                }
                client[fd] = c
                client[uid] = c
                websocket.write(fd, "{}")
            end
        end
    end

    function handle.message(fd, msg)
        local c = client[fd]
        if c and c.agent then
            local response = skynet.call(c.agent, "lua", "client", msg)
            send2client(c, response)
        else
            skynet.error("invlaid client:", fd, msg)
            websocket.close(fd)
        end
    end

    function handle.close(fd, code, reason)
        local c = client[fd]
        if c then
            c.fd = nil
            client[fd] = nil
            if c.agent then
                pcall(skynet.send, c.agent, "lua", "socket_close")                
            end
        end
        skynet.send(master, "lua", "an_client_disconnect")
        print("ws close from: " .. tostring(fd), code, reason)
    end

    function handle.error(fd)
        print("ws error from: " .. tostring(fd))
    end

    local function close_client(pid)
        local c = client[pid]
        if c then
            client[pid] = nil
            local fd = c.fd
            if fd then
                client[fd] = nil
                websocket.close(fd)
            end
        end
    end

    local commond = {}

    -- call by agent start
    function commond.close_client(pid)
        close_client(pid)
    end

    function commond.send_request(pid, msg)
        local c = client[pid]
        local ok, n = send2client(c, msg)
        if not ok and n >= 128 then
            close_client(pid)
        end
    end
    -- call by agent end

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