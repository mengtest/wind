local skynet = require "skynet"
local service = require "skynet.service"

local matchd = {}
local service_addr

-- p : {id:'123455', addr: 0x000001}
function matchd.start_match(p)
    return skynet.call(service_addr, "lua", "start_match", p)
end

function matchd.cancel_match(pid)
    return skynet.call(service_addr, "lua", "start_match", pid)
end

skynet.init(function()
    local matchd_service = function()
-- matchd service

local skynet = require "skynet"
local timer = require "wind.timer"
local uniqueid = require "wind.uniqueid"

local cancel_match_timer
local matching = {}
local match_queue = {}

local function match_timer()
    if #match_queue >= 3 then 
        table.sort(match_queue, function(a, b)
            return a.gold < b.gold
        end)

        local n = #match_queue//3
        for i=1,n do
            local players = {}
            for j=1,3 do
                table.insert(players, table.remove(match_queue))
            end
            local conf = {roomid = uniqueid.roomid.gen()}
            local room = skynet.newservice("room")
            skynet.send(room, "lua", "init", conf, players)
        end
    end
end

local commond = {}

function commond.start_match(p)
    if not matching[p.id] then
        table.insert(match_queue, p)
        matching[p.id] = true
    end
end

function commond.cancel_match(pid)
    if matching[pid] then
        for i,p in ipairs(match_queue) do
            if p.id == pid then
                table.remove(match_queue, i)
                matching[pid] = nil
                return
            end
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = commond[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
    cancel_match_timer = timer.create(100, match_timer, -1)
end)

-- end of matchd service
    end

    service_addr = service.new("matchd", matchd_service)
end)

return matchd