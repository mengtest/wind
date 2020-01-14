local skynet = require "skynet"
local agent = require "snax.agentserver"


local request = {}

function request:quit()
    agent.logout()
end

function request:hello()
    return {msg = "hello client"}
end


local commond = {}


local function init()
    skynet.error('------------init-------------------')
    skynet.timeout(200, function()
        agent.send_request("heartbeat", {msg = "hi"})
    end)
end

local function exit()
    skynet.error('------------exit-------------------')
end

agent.start {
    init = init,
    exit = exit,
    request = request,
    commond = commond
}