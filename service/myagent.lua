local skynet = require "skynet"
local agent = require "snax.agent"


local request = {}

function request:quit()
    agent.exit()
end

function request:hello()
    return {msg = "hello client"}
end


local commond = {}


local function init()
    skynet.error('------------init-------------------')
    skynet.timeut(200, function()
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