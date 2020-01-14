local skynet = require "skynet"
local agent = require "snax.agentserver"
local db = require "wind.mongo"

local me

local request = {}

function request:quit()
    agent.logout()
end

function request:hello()
    return {msg = "hello client"}
end


local commond = {}




local handle = {}




function handle.exit()
    skynet.error('------------exit-------------------')
end

function handle.start(id, addr)
    me = db.user.miss_find_one{id = id}
    me.login_time = os.time()
    me.login_ip = addr
    me.loginc = (me.loginc or 0) + 1
    dump(me)
end

function handle.init()
    skynet.error('------------init-------------------')
    skynet.timeout(200, function()
        agent.send_request("heartbeat", {msg = "hi"})
    end)
end

handle.request = request
handle.commond = commond

agent.start(handle)