local skynet = require "skynet"
local httpc = require "http.httpc"
local cjson = require "cjson"
local socket = require "skynet.socket"




local function main()

    local status, body = httpc.request("POST", "http://127.0.0.1:9015", "/", nil, nil, cjson.encode{"login", {tel = "13972143923"}})
    if status ~= 200 then
        return print(status)
    end
    local token = cjson.decode(body).token
    print("token:", token)

    local fd = socket.open("127.0.0.1", 8888)
    skynet.sleep(50)
    socket.write(fd, string.pack(">s2", "handshake"..token))
    print(socket.readline(fd))
    --
    --
    --
    local function send_request(name, args)
    	local pack = string.pack(">s2", cjson.encode{name, args})
    	socket.write(fd, pack)
    end

    send_request("hello", {msg = "world"})



    socket.close(fd)
end

skynet.start(main)