local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"

local mongo = {}
local service_addr

function mongo.insert(...)
    return skynet.call(service_addr, "lua", "insert", ...)
end

function mongo.remove(...)
    return skynet.call(service_addr, "lua", "remove", ...)
end

function mongo.find_one(...)
    return skynet.call(service_addr, "lua", "find_one", ...)
end

function mongo.find_all(...)
    return skynet.call(service_addr, "lua", "find_all", ...)
end

function mongo.update(...)
    return skynet.call(service_addr, "lua", "update", ...)
end

function mongo.sum(...)
    return skynet.call(service_addr, "lua", "sum", ...)
end

skynet.init(function()
    local mongo_service = function()

-- mongo service
local skynet = require "skynet"
local service = require "skynet.service"

skynet.start(function()
    local slave = {}
    local balance = 1
    skynet.dispatch("lua", function (_, _, ...)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
        local r = skynet.call(s, "lua", ...)
        skynet.ret(skynet.pack(r))
    end)

    local function mongo_worker ()
        local skynet = require "skynet"
        local mongo = require "skynet.db.mongo"
        local conf = require "config.mongo"
        
        local conn, db
        local command = {}
        
        function command.insert(coll_name, obj)
            return db[coll_name]:insert(obj)
        end
        
        function command.remove(coll_name, query)
            return db[coll_name]:delete(query)
        end
        
        function command.find_one(coll_name, query, fields)
            return db[coll_name]:findOne(query, fields)
        end
        
        function command.find_all(coll_name, query, fields, sorter, limit, skip)
            local t = {}
            local it = db[coll_name]:find(query, fields)
            if not it then
                return t
            end
        
            if sorter then
                if #sorter > 0 then
                    it = it:sort(table.unpack(sorter))
                else
                    it = it:sort(sorter)
                end
            end
        
            if limit then
                it:limit(limit)
                if skip then
                    it:skip(skip)
                end
            end
        
            while it:hasNext() do
                local obj = it:next()
                table.insert(t, obj)
            end
        
            return t
        end
        
        function command.update(coll_name, query, update, upsert, multi)
            return db[coll_name]:update(query, update, upsert, multi)
        end

        function command.sum(coll_name, query, key)
            local pipeline = {}
            if query then
                table.insert(pipeline,{["$match"] = query_tbl})
            end
           
            table.insert(pipeline,{["$group"] = {_id = false, [key] = {["$sum"] = "$" .. key}}})
           
            local result = db:runCommand("aggregate", coll_name, "pipeline", pipeline, "cursor", {}, "allowDiskUse", true)

            if result and result.ok and result.ok == 1 then
                if result.cursor and result.cursor.firstBatch then
                    local r = result.cursor.firstBatch[1]
                    return r and r[key] or 0
                end
            end
            return 0
        end

        skynet.start(function()
            skynet.dispatch("lua", function (_, _, cmd, ...)
                local f = assert(command[cmd], cmd)
                skynet.ret(skynet.pack(f(...)))
            end)

            conn = mongo.client(conf)
            conn:getDB(conf.db_name)
            db = conn[conf.db_name]
        end)
    end

    for i=1, skynet.getenv "thread" do
        table.insert(slave, service.new("mongo-slave"..i, mongo_worker))
    end
end)

-- end of mongo service
    end

    service_addr = service.new("mongo-master", mongo_service)
end)


local cache = {}

local function collection(coll)
    local c = cache[coll]
    if not c then
        c = setmetatable({}, {__index = setmetatable({}, {__index = function (_, k)
            return function (...)
                local f = assert(mongo[k], k)
                return f(coll, ...)
            end
        end})})
        cache[coll] = c
    end
    return c
end

return setmetatable({}, {__index = function(_, coll)
    return collection(coll)
end})