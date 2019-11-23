local skynet = require "skynet"
local websocket = require "http.websocket"
local wsserver = require "snax.wsserver"
local cjson = require "cjson"
local token = require "wind.token"
local db = require "wind.mongo"

local server = {
    name = "lobby_master",
    host = "0.0.0.0",
    port = 9012,
    protocol = "ws"
}

--
-- slave
--
local user = {}

local request = {}

function request:handshake(id)
    local ok, err, pid = token.auth(self.token)
    if not ok then
        skynet.fork(function()
            websocket.close(id)
        end)
        return {err = err}
    else
        local u = db.user.miss_find_one({id = pid})
        user[id] = u
        user[pid] = u
        return table.filter(u, {_id = false})
    end
end

function request:create_room(u)

end

function request:join_room(u)

end


local handle = {}

local function parse_msg(msg)
    local ok, data = pcall(cjson.decode, msg)
    if not ok then
        return false
    end

    local cmd, args = data[1], data[2]
    if not cmd or not request[cmd] then
        return false 
    end
    return cmd, args
end

local invalid_client = string.format('{"err":%d}', SYSTEM_ERROR.invalid_client)
local unknow_error = string.format('{"err":%d}', SYSTEM_ERROR.unknow)

function handle.message(id, msg)
    print(msg)
    local u = user[id]
    local cmd, args = parse_msg(msg)
    if not cmd or (not u and cmd ~= "handshake") then
        websocket.write(id, invalid_client)
        websocket.close(id)
    else
        local f = request[cmd]
        local ok, r = pcall(f, args, u or id, id)
        if ok then
            assert(type(r) == 'table', r)
            websocket.write(id, cjson.encode(r))
        else
            websocket.write(id, unknow_error)
        end
    end
end

function handle.connect(id)
    print("ws connect from: " .. tostring(id))
end

function handle.close(id, code, reason)
    print("ws close from: " .. tostring(id), code, reason)
end

function handle.error(id)
    print("ws error from: " .. tostring(id))
end


server.handle = handle
--
-- master
--
local command = {}

function server.command_handler(cmd, ...)
	local f = assert(command[cmd], cmd)
	return f(...)
end

wsserver(server)