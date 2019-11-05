local start = require "snax.httpserver"
local skynet = require "skynet"

local server = {
    host = "0.0.0.0",
    port = 9002,
    name = "http_master",
    protocol = "http"
}

function server.handler(method, header, path, query, body)
    print("msg:", method, header, path, query, body)

    return "hello client"
end


local command = {}

function command.inject(filename)
    require(filename)
end


function server.command_handler(cmd, ...)
	local f = assert(command[cmd])
	return f(...)
end


start(server)