local miss = require "miss-mongo"
local mongo = require "db.mongo"

local M = {}


local function miss(o)
	local query = {_id = o._id}
	local event = {}

	function event.assign(k, v)
		mongo.update(coll, query, {["$set"] = {[k] = v}})
	end

	function event.tpush(k, v)
		mongo.update(coll, query, {["$push"] = {[k] = v}})
	end

	function event.tinsert(k, index, v)
		mongo.update(coll, query, {["$push"] = {
			[k] = {
				["$each"] = {v},
				["$position"] = index
			}
		}})
	end

	function event.tpop(k, i)
		mongo.update(coll, query, {["$pop"] = {[k] = i}})
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
	local o = mongo.find_one(coll, ...)
	if o then
		return miss(o)
	end
end

function M.find_all(coll, ...)
	local obj_list = mongo.find_all(coll, ...)
	for i,o in ipairs(obj_list) do
		obj_list[i] = miss(o)
	end
	return obj_list
end


return setmetatable(M, {__index = mongo})