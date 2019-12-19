local skynet = require "skynet"
local websocket = require "http.websocket"
local cjson = require "cjson"
local ws_id

local function send_request(cmd, args)
    print("client send:", cmd)
    websocket.write(ws_id, cjson.encode{cmd, args})
    skynet.sleep(10)
    local resp, close_reason = websocket.read(ws_id)
    print("server: " .. (resp and resp or "[Close] " .. close_reason))
end



local function connect()
    ws_id = websocket.connect("ws://127.0.0.1:9013")
    print('111111111111111111')
    send_request("login", {id = "123456"})
    skynet.sleep(100)
    send_request("start_match")
end


skynet.start(function()
    connect()
end)