local skynet = require "skynet"
require "skynet.queue"
local websocket = require "http.websocket"
local wsserver = require "snax.wsserver"
local cjson = require "cjson"
local token = require "wind.token"
local db = require "wind.mongo"
local kvdb = require "wind.kvdb"
local timer = require "wind.timer"
local matchd = require "matchd"

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
local lock = {}

local request = {}

function request:handshake(id)
    local ok, err, pid = token.auth(self.token)
    if not ok then
        skynet.fork(function()
            websocket.close(id)
        end)
        return {err = err}
    else
        local base = db.user.miss_find_one({id = pid})
        local u = {
            sock_id = id,
            base = base,
            room_addr = kvdb.user_room.get(pid)
        }
        user[id] = u
        user[pid] = u
        local r = table.filter(base, {_id = false}
        if u.room_addr then
            local ok, room_info = pcall(skynet.call, u.room_addr, "lua", "join", pid)
            if ok then
                r.room = room_info
            else
                -- room maybe has been dissolved
                u.room_addr = nil
                kvdb.user_room.set(pid, nil)
                skynet.error("try join room err"..room_info)
            end
        end
        return r
    end
end

--[[
function request:create_room(u)
end

function request:join_room(u)
end]]

function request:start_match(u)
    if u.room_addr then
        return {err = GAME_ERROR.in_other_room}
    else
        matchd.start_match{id = u.id, addr = skynet.self()}
        return {}
    end
end


local handle = {}

local function parse_msg(msg)
    local ok, data = pcall(cjson.decode, msg)
    if not ok then
        return false
    end

    local id, cmd, args = data[1], data[2], data[3]
    if not cmd or not request[cmd] then
        return false 
    end
    return id, cmd, args
end

local invalid_client = string.format('{"err":%d}', SYSTEM_ERROR.invalid_client)

function handle.message(id, msg)
    local u = user[id]
    local msg_id, cmd, args = parse_msg(msg)
    if not msg_id or (not u and cmd ~= "handshake") then
        websocket.write(id, invalid_client)
        websocket.close(id)
    else
        local lk = lock[id]
        lk(function()
            local f = request[cmd]
            if f then
                local ok, r = pcall(f, args, u or id)
                if ok then
                    assert(type(r) == 'table', r)
                    websocket.write(id, cjson.encode{msg_id, r})
                else
                    skynet.error(r)
                    websocket.write(id, cjson.encode{msg_id, {err = SYSTEM_ERROR.unknow}})
                end
            else
                assert(u)
                if u.room_addr then
                    skynet.send(u.room_addr, "lua", "player_request", {action = cmd, args = args})
                end
            end
        end)
    end
end

function handle.connect(id)
    print("ws connect from: " .. tostring(id))
    lock[id] = skynet.queue()
end

function handle.close(id, code, reason)
    print("ws close from: " .. tostring(id), code, reason)
    lock[id] = nil
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