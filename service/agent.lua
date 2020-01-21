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
    local self = setmetatable({}, {__index = me})

    function self.self()
        return me
    end
    
    function self.add_gold(num, desc)
        local start_num = me.gold
        me.gold = me.gold + num
        db.gold_rec.insert{
            pid = me.id,
            time = os.time(),
            start_num = start,
            end_num = me.gold,
            desc = desc
        }
    end

    function self.add_diamond(num, desc)
        local start_num = me.diamond
        me.diamond = me.diamond + num
        db.diamond_rec.insert{
            pid = me.id,
            time = os.time(),
            start_num = start,
            end_num = me.diamond,
            desc = desc
        }
    end

    local function find_goods_in_backpack(id)
        for i,v in ipairs(me.backpack) do
            if v.id == id then
                return v
            end
        end
    end

    function self.add_rewards(rewards, desc)
        local now = os.time()
        for i,v in ipairs(rewards) do
            if v.id == "gold" then
                self.add_gold(v.num, desc)
            elseif v.id == "diamond" then
                self.add_diamond(v.num, desc)
            else
                local goods = find_goods_in_backpack(v.id)
                local start_num
                if goods then
                    start_num = goods.num
                    GOODS_ADD(goods, v)
                else
                    goods = GEN_ZERO_GOODS(v.id)
                    goods = GOODS_ADD(goods, v)
                    table.insert(me.backpack, goods)
                end
            end
        end
    end


    lobby(self, request, command)
end

function handle.init()
    skynet.error('------------ init ------------')
end

agent.start(handle)