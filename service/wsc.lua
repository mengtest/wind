local skynet = require "skynet"
local websocket = require "http.websocket"
local httpc = require "http.httpc"
local cjson = require "cjson"
local ws_id
local me



local function connect_gate()
    ws_id = websocket.connect("ws://127.0.0.1:8888", {token = "TOKEN123"})
    print("connect server ws_id:", ws_id)

    local t1 = skynet.hpc()
    websocket.write(ws_id, "hello world")
    local resp, close_reason = websocket.read(ws_id)
    print(((skynet.hpc() - t1) /1000000) .. "ms" )
    print("server: " .. (resp and resp or "[Close] " .. close_reason))
end

skynet.start(function()
    skynet.fork(connect_gate)
end)