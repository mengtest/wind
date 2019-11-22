local skynet = require "skynet"
local cjson = require "cjson"
local web = require "snax.webserver"
local db = require "wind.mongo"
local token = require "wind.token"

local server = {
    host = "0.0.0.0",
    port = 9002,
    name = "game_master",
    protocol = "http"
}

--
-- slave
--

local request = {}


local function register(id)
	local u = {
		id = assert(id),
		gold = 0,
		diamond = 0,
	}

	db.user.insert(u)
	return u
end

function request:login()
	local u = db.user.find_one({id = self.id})
	if not u then
		u = register(self.id)
	end

	u.token = token.encode(self.id, os.time())

	return {
		token = u.token,
		id = u.id,
		gold = u.gold,
		diamond = u.diamond
	}
end


local invalid_client = string.format('{"err":%d}', SYSTEM_ERROR.invalid_client)
local unknow_error = string.format('{"err":%d}', SYSTEM_ERROR.unknow)

local unneed_auth_request = {
	["login"] = true,
}


function server.request_handler(method, header, path, query, body)
	if method == 'GET' then
		return invalid_client_error
	end

	local cmd, args, u

	cmd = string.gsub(path:sub(2, #path), "/", "_")
	local req = request[cmd]
	if not req then
		return invalid_client
	end

	if body and body ~= "" then
		local ok, t = pcall(cjson.decode, body)
		if ok then
			args = t
		else
			return invalid_client
		end
	end

	if not unneed_auth_request[cmd] then
		local ok, err, user = token.auth(header.token)
		if not ok then
			return string.format('{"err": %d}', err)
		end
		u = user
	end

	local ok, r = pcall(req, args, u)
	if ok then
		assert(type(r) == 'table')
		return cjson.encode(r)
	else
		skynet.error("request error:", r)
		return unknow_error
	end
end

--
-- master
--

local command = {}


function server.command_handler(cmd, ...)
	local f = assert(command[cmd], cmd)
	return f(...)
end


web(server)