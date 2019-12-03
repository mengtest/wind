local skynet = require "skynet"
local service = require "skynet.service"

local function kvdb_service()
	local skynet = require "skynet"
	local db = {}

	local command = {}

	function command.get(key)
		return db[key]
	end

	function command.set(key, value)
		db[key] = value
	end

	skynet.dispatch("lua", function(session, address, cmd, ...)
		skynet.ret(skynet.pack(command[cmd](...)))
	end)
end


local cache = {}

local function query_db(db_name)
	local db = cache[db_name]
	if not db then
		local service_addr = service.new(db_name, kvdb_service)
		db = {}

		function db.set(k, v)
			skynet.call(service_addr, "lua", "set", k, v)
		end

		function db.get(k)
			return skynet.call(service_addr, "lua", "get", k)
		end
		cache[db_name] = db
	end
	return db
end


return setmetatable({}, {__index = function (_, db_name)
	return query_db('kvdb-'..db_name)
end})