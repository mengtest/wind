local miss = require "miss-mongo"
local mongo = require "db.mongo"

local M = {}


local function miss_one(coll, o)
	local query = {_id = o._id}
	local event = {}
	local collection = mongo[coll]

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


function M.find_one(coll, ...)
	local o = mongo[coll].find_one(...)
	if o then
		return miss_one(coll, o)
	end
end

function M.find_all(coll, ...)
	local obj_list = mongo[coll].find_all(...)
	for i,o in ipairs(obj_list) do
		obj_list[i] = miss_one(coll, o)
	end
	return obj_list
end

local function mongo_collection(coll)
	return setmetatable({}, {__index = function(_, key)
		return function(...)
			local f = M[key]
			if f then
				return f(coll, ...)
			else
				return mongo[coll][key](...)
			end
		end
	end})
end


return setmetatable({}, {__index = function(_, coll)
	return setmetatable({}, {__index = mongo_collection(coll)})
end})