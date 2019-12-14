local skynet = require "skynet"
local cjson = require "cjson"
local web = require "snax.webserver"
local db = require "wind.mongo"
local token = require "wind.token"

------------------------------------------------------------------------
-- request
------------------------------------------------------------------------

local request = {}

function request:login()
	local account = assert(self.account)
	local password = assert(self.password)
	
	local u = db.admin_user.miss_find_one {account = account}
	if not u then
		return {err = "account non-existent"}
	end
	if password ~= u.password then
		return {err = "bad password"}
	end
	local t = token.encode(account)
	
	return {token = t}
end

function request:refresh_token()
	local t, err = token.refresh(assert(self.token))
	return {
		token = t,
		err = err
	}
end

function request:test()
	local account, err = token.auth(self.token) 
	return {
		msg = "hello i'm wind-admin",
		account = account,
		err = err
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
    name = "admin-master",
    host = "0.0.0.0",
    port = 9011,
    protocol = "http",
    request = request,
    commond = commond
}