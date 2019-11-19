local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local db = require "wind.mongo"
local token = require "util.token"


function response.auth(t)
    
    local pid, time = token.decode(t)
    if not pid then
        return false, "invalid token"
    end

    local u = db.user.find_one({id = pid})
    if not u or u.token ~= t then
        return false, "invalid token"
    end

    if os.time() - time > 15*60 then
        return false, "expired token"
    end

    return true
end



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
    skynet.error(string.format("loginserver listen at %s:%s", host, port))

    socket.start(id, function(id, addr)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
        s.post.request(id)
    end)
end