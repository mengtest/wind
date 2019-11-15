local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local webstart = require "util.webhelper"
local cjson = require "cjson"


local request = {}


function request:login()
	return {id = 'windy', head = self.head}
end


local function auth_token(token)
	return true
end


local unlimited_request = {
	['/login'] = true
}

function accept.request(id)
	local ok, method, header, path, query, body, respone = webstart(id)
	if not ok then
		skynet.error(method)
	else
		if method == 'GET' then
			return respone('{"err": "GET is not supported"}')
		end
	
		local args
		if body and body ~= "" then
			local ok, t = pcall(cjson.decode, body)
			if not ok then
				return respone('{"err": "request body must been an json object"}')
			else
				args = t
			end
		end
	
		local underline_path = string.gsub(path:sub(2, #path), "/", "_")
		local f = request[underline_path]
		if not f then
			return respone('{"err": "cannot find handler by:'..path..'"}')
		end
	
		if not unlimited_request[path] then
			local ok, err = auth_token(header.token)
			if not ok then
				return respone('{"err": "auth token failed"}')
			end
		end
		
		respone(cjson.encode(f(args)))
	end
end


function init()
end