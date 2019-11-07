local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"


local slave = {}
local balance = 1


function init(conf)
    local instance = conf.instance or skynet.getenv "thread"
    local host = conf.host or "0.0.0.0"
    local port = assert(tonumber(conf.port))
    local worker = assert(conf.worker)

    for i=1,instance do
        slave[i] = snax.newservice(worker)
    end

    local id = socket.listen(host, port)
    skynet.error(string.format("webserver listen at %s:%s", host, port))

    socket.start(id, function(id, addr)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
        s.post.request(id)
    end)
end