local skynet = require "skynet"
local cjson = require "cjson"
local web = require "snax.webserver"
local db = require "wind.mongo"
local token = require "wind.token"
local uniqueid = require "wind.uniqueid"

------------------------------------------------------------------------
-- request
------------------------------------------------------------------------

local request = {}

function request:login()
	local tel = assert(self.tel)
	local u = db.user.find_one({tel = tel}, {_id = false})
	if not u then
		local uid = uniqueid.gen("userid") 
		u = {
			tel = tel,

			-- user data
			id = uid,
			nickname = "玩家"..uid,
			gold = 0,
			diamond = 0
		}
		db.user.insert(u)
	end
	return {token = token.encode(u.id)}
end

------------------------------------------------------------------------
-- commond
------------------------------------------------------------------------
local commond = {}

function commond.hello()
	return "world"
end

web {
    name = "login-master",
    host = "0.0.0.0",
    port = 9015,
    protocol = "http",
    request = request,
    commond = commond
}