local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local webstart = require "util.webhelper"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local mongo = require "wind.mongo"

local function token_encode(pid, time)
	return crypt.base64encode(pid)..'@'..crypt.base64encode(time)
end

local function token_decode(token)
	local pid, time = s:match("(%d+)@(%d+)")
	if pid and time then
		return crypt.base64decode(pid), tonumber(crypt.base64decode(time))
	end
end

local request = {}


function request:login()
	local pid = assert(self.id)
	local u = mongo.find_one(COLL.user, {id = pid})
	if u then
		local token = token_encode(pid, os.time())
		u.token = token
		return {token = token}
	else
		return {err = AUTH_ERROR.account_not_exist}
	end
end


local function auth_token(token)
	local now = os.time()
	local pid, time = token_decode(token)
	if not pid then
		return false, AUTH_ERROR.invalid_token
	else
		local u = mongo.find_one(COLL.user, {id = pid})
		if not u or u.token ~= token then
			return false, AUTH_ERROR.invalid_token
		else
			if now - time > TOKEN.expires_time then
				return false, AUTH_ERROR.token_expires
			else
				return true
			end
		end
	end
end


local unlimited_request = {
	['login'] = true
}

function accept.request(id)
	local ok, method, header, path, query, body, respone = webstart(id)
	if not ok then
		skynet.error(method)
	else
		if method == 'GET' then
			return respone(string.formate('{"err": %d}', SYSTEM_ERROR.invalid_client))
		end
	
		local args
		if body and body ~= "" then
			local ok, t = pcall(cjson.decode, body)
			if not ok then
				return respone(string.formate('{"err": %d}', SYSTEM_ERROR.decode_failure))
			else
				args = t
			end
		end
	
		local underline_path = string.gsub(path:sub(2, #path), "/", "_")
		local f = request[underline_path]
		if not f then
			return respone(string.formate('{"err": %d}', SYSTEM_ERROR.argument))
		end
	
		if not unlimited_request[underline_path] then
			local ok, err = auth_token(header.token)
			if not ok then
				return respone(string.formate('{"err": %d}', err))
			end
		end
		
		respone(cjson.encode(f(args)))
	end
end


function init()
end