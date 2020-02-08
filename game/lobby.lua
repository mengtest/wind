local db = require "wind.mongo"
local lobby_active = require "game.lobby_active"
local ec = require "wind.eventcenter-local"

local function load_moudle(...)
	lobby_active(...)
end


return function (me, request, command)

    local I = setmetatable({}, {__index = me})

	-- Interface Start
    function I.self()
        return me
    end
    
    function I.add_gold(num, desc)
        local start_num = me.gold
        me.gold = me.gold + num
        db.gold_rec.insert{
            pid = me.id,
            time = os.time(),
            start_num = start_num,
            end_num = me.gold,
            desc = desc
        }
    end

    function I.add_diamond(num, desc)
        local start_num = me.diamond
        me.diamond = me.diamond + num
        db.diamond_rec.insert{
            pid = me.id,
            time = os.time(),
            start_num = start_num,
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

    function I.add_rewards(rewards, desc)
        local now = os.time()
        for i,v in ipairs(rewards) do
            if v.id == "gold" then
                I.add_gold(v.num, desc)
            elseif v.id == "diamond" then
                I.add_diamond(v.num, desc)
            else
                local goods = find_goods_in_backpack(v.id)
                local start_num
                if goods then
                    start_num = (v.id == "jipaiqi_tian") and goods.expiry_time or goods.num
                    goods = GOODS_ADD(goods, v)
                else
                    start_num = 0
                    goods = GOODS_GEN_ZERO(v.id)
                    goods = GOODS_ADD(goods, v)
                    table.insert(me.backpack, goods)
                end
                end_num = (v.id == "jipaiqi_tian") and goods.expiry_time or goods.num
                db.goods_rec.insert{
                    pid = me.id,
                    goods_id = v.id,
                    time = os.time(),
                    start_num = start_num,
                    end_num = end_num,
                    desc = desc
                }
            end
        end
	end

	-- Other moudle
	load_moudle(I, request, command)

	-- API Start
	function request:base_info()
		return table.filter(me, {_id = false})
	end

	function command.send2client(name, args)
	    agent.send_request(name, args)
    end
    
    -- 处理登录事件
    ec.sub_once({type = "login"}, function(e)
        me.login_time = e.time
        me.login_ip = e.ip
        me.loginc = me.loginc + 1
    end)
end