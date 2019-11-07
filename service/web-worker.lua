local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local webstart = require "util.webhelper"




local function handler(method, header, path, query, body)
    print(method, header, path, query, body)
    dump(header, query)
    return "ok"
end


function accept.request(id)
	local ok, err = webstart(id, handler)
	if not ok then
		skynet.error(err)
	end
end


function init()

end