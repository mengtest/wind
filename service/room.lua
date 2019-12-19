local skynet = require "skynet"
local lock = (require "skynet.queue")()
-----------------------------------------------------------------
local db = require "wind.mongo"
local room = {}

-- UTIL
local function send_push(p, name, args)
    skynet.send(p.addr, "lua", "send_push", name, args)
end

local function room_radio(name, args)
    for _,p in ipairs(room.players) do
        send_push(p, name, args)
    end
end

local function room_info()
    local r = {
        id = room.id,
        players = {}
    }
    for _,p in ipairs(room.players) do
        table.insert(r.players, {
            id = p.id,
            nickname = p.base.nickname,
            gold = p.base.gold
        })
    end
    return r
end

local function room_init(conf, players)
    room.conf = conf
    room.id = assert(conf.roomid)
    room.players = {}
    if players then
        for i,p in ipairs(players) do
            p.chair = i
            p.base = db.user.miss_find_one{id = p.id}
            table.insert(room.players, p)
        end
        room_radio("join_room", room_info())
    end
end

local function find(pid)
    for i,p in ipairs(room.players) do
        if p.id == pid then
            return p
        end
    end
end

-- REQUEST START
local request = {}

function request:ready(pid)
    local p = find(pid)
end
-----------------------------------------------------------------
local commond = {}

function commond.shutdown()
end

function commond.player_request(args)
end

function commond.join(u)
end

function commond.init(conf, players)
    room_init(conf, players)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, args)
        lock(function()
            local f = commond[cmd]
            skynet.ret(skynet.pack(f(args)))
        end)
    end)
end)