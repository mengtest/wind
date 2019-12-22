local skynet = require "skynet"
local websocket = require "http.websocket"
local httpc = require "http.httpc"
local cjson = require "cjson"
local ws_id
local me

print = skynet.error

local function send_request(cmd, args)
    print("client send:", cmd)
    websocket.write(ws_id, cjson.encode{cmd, args})
    skynet.sleep(10)
    local resp, close_reason = websocket.read(ws_id)
    print("server: " .. (resp and resp or "[Close] " .. close_reason))
end

local function login(tel)
    local status, body = httpc.request("POST", "http://127.0.0.1:9015", "/", nil, nil, cjson.encode{
        "login", {tel = tel}
    })
    if status == 200 then
        return true, cjson.decode(body)
    end
    print("login failure, status:", status)
    return false, status
end

local function connect_gate()
    ws_id = websocket.connect("ws://127.0.0.1:9013", {token = me.token})
    if ws_id then
        local resp, close_reason = websocket.read(ws_id)
        if resp then
            local r = cjson.decode(resp)
            dump("handshake result:", r)
            if r.err then
                print("handshake error:", r.err)
            else
                return true
            end
        else
            print("handshake error, socket closed", close_reason)
        end
    end
end

local function start_read_message()
    skynet.fork(function ()
        while true do
            skynet.sleep(100)
            local resp, close_reason = websocket.read(ws_id)
            print("server: " .. (resp and resp or "[Close] " .. close_reason))
        end
    end)
end


local function connect()
    local ok, u = login("13972143923")
    if ok then
        me = u
        dump(me)
        if not connect_gate() then
            return
        end
    end

    start_read_message()
    send_request("start_match")
end


skynet.start(function()
    skynet.fork(connect)
end)