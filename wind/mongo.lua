local miss = require "miss-mongo"
local db = require "db.mongo"

local M = {}


local function miss_one(coll, o)
	local query = {_id = o._id}
	local event = {}
	local collection = db[coll]

	function event.assign(k, v)
		collection.update(query, {["$set"] = {[k] = v}})
	end

	function event.tpush(k, v)
		collection.update(query, {["$push"] = {[k] = v}})
	end

	function event.tinsert(k, index, v)
		collection.update(query, {["$push"] = {
			[k] = {
				["$each"] = {v},
				["$position"] = index
			}
		}})
	end

	function event.tpop(k, i)
		collection.update(query, {["$pop"] = {[k] = i}})
	end

	local function handler(e, ...)
		print("miss:", e, ...)
		local f = event[e]
		f(...)
	end

	local proxy = miss.miss(o, handler)
	return proxy
end


function M.miss_find_one(coll, ...)
	local o = db[coll].find_one(...)
	if o then
		return miss_one(coll, o)
	end
end

function M.miss_find_all(coll, ...)
	local obj_list = db[coll].find_all(...)
	for i,o in ipairs(obj_list) do
		obj_list[i] = miss_one(coll, o)
	end
	return obj_list
end

function M.miss_insert(coll, o)
	o._id = db[coll].insert(o)
	return miss_one(coll, o)
end

local cache = {}

local function collection(coll)
    local c = cache[coll]
    if not c then
        c = setmetatable({}, {__index = setmetatable({}, {__index = function (_, k)
            return function (...)
				local f = M[k]
				if f then
					return f(coll, ...)
				else
					return db[coll][k](...)
				end
            end
        end})})
        cache[coll] = c
    end
    return c
end

return setmetatable({}, {__index = function(_, coll)
    return collection(coll)
end})