local skynet = require "skynet"
local agent = require "snax.agentserver"
local db = require "wind.mongo"
local lobby = require "game.lobby"
local ec = require "wind.eventcenter-local"

local handle = {}
local request = {}
local command = {}

function command.send2client(name, args)
    agent.send_request(name, args)
end

function handle.request(cmd, args)
    local f = assert(request[cmd], cmd)
    return f(args)
end

function handle.command(cmd, ...)
    local f = assert(command[cmd], cmd)
    return f(...)
end

function handle.exit()
    ec.pub{type = "exit", time = os.time()}
    skynet.error('------------ exit ------------')
end

function handle.start(id, addr)
    me = db.user.miss_find_one{id = id}
    me.login_time = os.time()
    me.login_ip = addr
    me.loginc = me.loginc + 1

    -- load loginc module
    lobby(me, request, command)
end

function handle.init()
    skynet.error('------------ init ------------')
end

agent.start(handle)