local skynet = require "skynet"
local cjson = require "cjson"
local web = require "snax.webserver"
local db = require "wind.mongo"
local token = require "wind.token"



local function register(id, token)
	db.wind_user.insert {id = id, token = token}

	-- todo: init your user here
	db.user.insert {
		id = id,
		gold = 50000,
		diamond = 0
	}
end

------------------------------------------------------------------------
-- request
------------------------------------------------------------------------

local request = {}

function request:login()
	local pid = assert(self.id)
	local t = token.encode(pid, os.time())
	local u = db.wind_user.miss_find_one({id = pid})
	if u then
		u.token = t
	else
		register(pid, t)
	end
	return {
		id = pid,
		token = t
	}
end

function request:test()
	return {
		msg = "hello i'm loginserver"
	}
end

------------------------------------------------------------------------
-- commond
------------------------------------------------------------------------
local commond = {}

function commond.hello()
	return "world"
end

web {
    name = "logind-master",
    host = "0.0.0.0",
    port = 9011,
    protocol = "http",
    request = request,
    commond = commond
}