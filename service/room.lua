local skynet = require "skynet"
local lock = (require "skynet.queue")()
-----------------------------------------------------------------
local room = {}

-- UTIL
local function room_init(conf)
    room.conf = conf
    room.id = assert(conf.roomid)
    room.players = {}
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

function request:leave(pid)
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

function commond.init(conf)
    room_init(self)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, args)
        lock(function()
            local f = commond[cmd]
            skynet.ret(skynet.pack(f(args)))
        end)
    end)
end)