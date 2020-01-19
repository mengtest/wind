--[[
    跨服务的事件中心
]]
local skynet = require "skynet"
local service = require "skynet.service"

local ec = {}
local service_addr

local subscriber = {}

function ec.sub(pattern, callback, limit)
    limit = limit or math.huge
    local u = {pattern = pattern, callback = callback, limit = limit, count = 0}
    local id = tostring(u):sub(10, -1) -- "0x123456789012"
    skynet.call(service_addr, "lua", "SUB", id, pattern, limit)
    subscriber[id] = u

    function u.unsub()
        local u = subscriber[id]
        if u then
            subscriber[id] = nil
            skynet.send(service_addr, "lua", "UNSUB", id)
        end
    end

    return u
end

function ec.sub_once(pattern, callback)
    return ec.sub(pattern, callback, 1)
end

function ec.pub(event)
    skynet.send(service_addr, "lua", "PUB", event)
end


skynet.init(function()

    local function eventcenter_service()
-- ec start
local skynet = require "skynet"

local subscriber = {}
local type_map = {}              
local commond = {}

function commond.SUB(source, id, pattern)
    local key = source..id
    local event_type = pattern.type
    subscriber[event_type] = subscriber[event_type] or {}
    subscriber[event_type][key] = {source = source, id = id, pattern = pattern}
    type_map[key] = event_type
end

local function unsub(source, id)
    local key = source..id
    local event_type = type_map[key]
    if event_type then
        type_map[key] = nil
        local list = assert(subscriber[event_type])
        list[key] = nil
    end
end

function commond.UNSUB(source, id)
    unsub(source, id)
end

local function match(event, pattern)
    for k,v in pairs(pattern) do
        if event[k] ~= v then
            return false
        end
    end
    return true
end

function commond.PUB(source, event)
    event.source = source
    local event_type = event.type
    local list = subscriber[event_type]
    if list then
        for _,u in pairs(list) do
            if match(event, u.pattern) then
                local ok = pcall(skynet.send, u.source, "wd_event", u.id, event)
                if not ok then
                    -- u maybe exited
                    unsub(u.source, u.id)
                end
            end
        end
    end
end

skynet.register_protocol {
    name = "wd_event",
    id = 255,
    pack = skynet.pack
}

skynet.start(function() 
    skynet.dispatch("lua", function(_,source, cmd, ...)
        local f = commond[cmd]
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)
end)
-- ec end
    end

    skynet.register_protocol {
        name = "wd_event",
        id = 255,
        unpack = skynet.unpack,
        dispatch = function(_, _, id, event)
            local u = subscriber[id]
            if u then
                u.callback(event)
                u.count = u.count + 1
                if u.count == u.limit then
                    u.unsub()
                end
            end
        end
    }
    service_addr = service.new("eventcenter", eventcenter_service)
end)



return ec