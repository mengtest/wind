local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local helper = require "util.webhelper"

local call


local function handler(method, header, path, query, body)
    print(method, header, path, query, body)
    return "ok"
end


function accept.request(id)
    call(id)
end


function init()
    call = helper("http", handler)
end