local skynet = require "skynet"
local httpc = require "http.httpc"
local cjson = require "cjson"
local socket = require "skynet.socket"

local TOKEN, fd
print = skynet.error

local function login(tel)
    local status, body = httpc.request("POST", "http://127.0.0.1:9015", "/", nil, nil, cjson.encode{"login", {tel = tel}})
    if status ~= 200 then
        return print(status)
    end
    local token = cjson.decode(body).token
    return token
end

local function connect()
    fd = socket.open("127.0.0.1", 8888)
    skynet.sleep(50)
    socket.write(fd, string.pack(">s2", TOKEN))
    local ok = socket.readline(fd)
    if ok == '200 OK' then
        print("connect gameserver ok")
        return true
    else
        print("connect gameserver failed", ok)
    end
end


local function send_request(name, args)
    local pack = string.pack(">s2", cjson.encode{name, args})
    socket.write(fd, pack)
end


local function main()

    local token = login("13972143923")
    if not token then
        return
    else
        TOKEN = token
        print("login suc ...")
    end

    connect()
    socket.close(fd)
    connect()
    -- send_request("hello", {msg = "world"})



    
end

skynet.start(main)