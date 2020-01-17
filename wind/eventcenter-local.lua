--[[
    本服务内的事件中心
]]

local ec = {}


local subscriber = {}

function ec.sub(pattern, callback, limit)
    limit = limit or math.huge
    local event_type = assert(pattern.type)
    subscriber[event_type] = subscriber[event_type] or {}
    local list = subscriber[event_type]
    local u = {pattern = pattern, callback = callback, limit = limit, count = 0}
    table.insert(list, u)

    local function unsub()
        for i,v in ipairs(list) do 
            if v == u then
                return table.remove(list, i)
            end
        end
    end
    return unsub
end

function ec.sub_once(pattern, callback)
    return ec.sub(pattern, callback, 1)
end


local function match(event, pattern)
    for k,v in pairs(pattern) do
        if event[k] ~= v then
            return false
        end
    end
    return true
end

function ec.pub(event)
    local event_type = assert(event.type)
    local sub_list = subscriber[event_type]
    if sub_list then
        local unsub_list = {}
        for i,u in ipairs(sub_list) do 
            if match(event, u.pattern) then 
                u.callback(event)
                u.count = u.count + 1
                if u.count == u.limit then
                    table.insert(unsub_list, i)
                else
                    assert(u.limit > u.count)
                end
            end
        end
        for i=#unsub_list, 1, -1 do
            table.remove(sub_list, unsub_list[i])
        end
    end
end


return ec