local skynet = require "skynet"
local cjson = require "cjson"
local web = require "snax.webserver"
local db = require "wind.mongo"
local token = require "wind.token"

local server = {
    host = "0.0.0.0",
    port = 9011,
    name = "login_master",
    protocol = "http"
}

--
-- slave
--

local request = {}


local function register(id, token)
	db.wind_user.insert {id = id, token = token}

	-- todo: init your user here
	db.user.insert {
		id = id,
		gold = 50000,
		diamond = 0
	}
end

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


local invalid_client = string.format('{"err":%d}', SYSTEM_ERROR.invalid_client)
local unknow_error = string.format('{"err":%d}', SYSTEM_ERROR.unknow)

local unneed_auth_request = {
	["login"] = true,
}


function server.request_handler(method, header, path, query, body)
	print(path, body)
	if method == 'GET' then
		return invalid_client
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

	local ok, r = pcall(req, args or {}, u)
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