--[[
    设计:
    1.调用 encode 生成一个 token, 有效期2天(可自定义), 之后可以调用 refresh(token),
        每次刷新都会返回一个新的 token(刷新次数会增加, token有效期还是2天)
    2.客户端启动:
        1. 本地没有 token, 走登录流程 拿到token
        2. 本地有 token, 发一个 refresh_token 协议:
            成功: 返回新的token
            失败: 走登录流程 (假设你0点登录, 下一次是48小时后登录, 才会需要重新登录)

    tip: 刷新次数有限制
    tip: 优点1, 如果客户端不小心发了一个旧的token(上一次的合法token), 如果该token 还有效, 则通过校验
]]
local skynet = require "skynet"
local service = require "skynet.service"
local db = require "wind.mongo"
local crypt = require "skynet.crypt"

local base64decode = crypt.base64decode

local token = {}
local service_addr

function token.gen(id)
	return skynet.call(service_addr, "lua", "gen", id)
end

function token.decode(t)
    local id, time, refresh_times = t:match("(.+)#(.+)@(.+)")
    if refresh_times then
        return base64decode(id), tonumber(base64decode(time)), tonumber(base64decode(refresh_times))
    end
end

function token.auth(t)
    if not t then
        return nil, AUTH_ERROR.invalid_token
    else
        return skynet.call(service_addr, "lua", "auth", t)
    end
end

function token.refresh(t)
    return skynet.call(service_addr, "lua", "refresh", t)
end

skynet.init(function()
    local token_service = function()
-- token service
local skynet = require "skynet"
local db = require "wind.mongo"
local crypt = require "skynet.crypt"
local timer = require "wind.timer"

local EXPIRES_TIME = 2*24*60*60                           -- 建议不要太短, 如果太短(假设2小时, 玩家离线后2小时就失效, 失效后也无法刷新, 必须登录, 影响体验)
local REFRESH_MAX_TIMES = 30*24*60*60 // EXPIRES_TIME     -- 理论可以一直刷新到30天 后才需要登录

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode

local function encode(id, time, refresh_times)
    refresh_times = refresh_times or 0
    return base64encode(id).."#"..base64encode(time).."@"..base64encode(refresh_times)
end

local function decode(t)
	local id, time, refresh_times = t:match("(.+)#(.+)@(.+)")
	if refresh_times then
		return base64decode(id), tonumber(base64decode(time)), tonumber(base64decode(refresh_times))
	end
end


local user = {}    -- id -> {old_token, cur_token, db_obj}

local commond = {}

function commond.gen(id)
    local now = os.time()
    local expires_time = now + EXPIRES_TIME
    local t = encode(id, now)
    local u = user[id]
    if u then
        u[1] = u[2]
        u[2] = t
        u[3].token = t
        u[3].expires_time = expires_time
    else
        u = {nil, t}
        u[3] = db.wind_token.miss_find_one {id = id}
        if u[3] then
            u[3].token = t
            u[3].expires_time = expires_time
        else
            u[3] = db.wind_token.miss_insert{id = id, token = t, expires_time = expires_time}
        end
        user[id] = u
    end
    return t
end

function commond.refresh(t)
    local id, time, refresh_times = commond.auth(t)
    if not id then
        return nil, time
    end
    local u = user[id]

    if t == u[2] then
        refresh_times = refresh_times + 1
        if refresh_times <= REFRESH_MAX_TIMES then
            local now = os.time()
            local new_token = encode(id, now, refresh_times)
            u[1] = u[2]
            u[2] = new_token
            u[3].token = new_token
            u[3].expires_time = now + EXPIRES_TIME
            return new_token
        else
            return nil, AUTH_ERROR.token_refresh_overlimit
        end
    else
        return nil, AUTH_ERROR.invalid_token
    end
end

function commond.auth(t)
    local now = os.time()
    local id, time, refresh_times = decode(t)
    local u = id and user[id]
    if not u then
        return nil, AUTH_ERROR.invalid_token
    end

    if t == u[2] or t == u[1] then
        if now - time <= EXPIRES_TIME then
            return id, time, refresh_times
        else
            return nil, AUTH_ERROR.token_expires
        end
    else
        return nil, AUTH_ERROR.invalid_token
    end
end

local function load_token()
    local tokens = db.wind_token.miss_find_all{expires_time = {["$gt"] = os.time()}}

    local now = os.time()
    for _,token in ipairs(tokens) do
        local dt = token.expires_time - now
        if dt > 0 then
            user[token.id] = {nil, token.token, token}
        end
    end
end

-- 30分钟清理一次失效 token
local function start_clear()
    timer.create(30*60*100, function ()
        local now = os.time()
        user = table.filter(user, function (_, u)
            return u[3].expires_time >= now
        end)
    end, -1)
end

skynet.start(function() 
    load_token()
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = assert(commond[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
    start_clear()
end)

-- end of token service
    end

    service_addr = service.new("token", token_service)
end)

return token