local skynet = require "skynet"
local service = require "skynet.service"
local db = require "wind.mongo"
local crypt = require "skynet.crypt"

local base64decode = crypt.base64decode

local token = {}
local service_addr

function token.encode(id)
	return skynet.call(service_addr, "lua", "create", id)
end

function token.decode(t)
	local id, time = t:match("(.+)#(.+)")
	if time then
		return base64decode(id), base64decode(time)
	end
end

function token.auth(t)
    if not t then
        return nil, AUTH_ERROR.invalid_token
    else
        return skynet.call(service_addr, "lua", "auth", t)
    end
end

skynet.init(function()
    local token_service = function()
-- token service
local skynet = require "skynet"
local db = require "wind.mongo"
local crypt = require "skynet.crypt"
local timer = require "wind.timer"

local EXPIRES_TIME = 15 * 60

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode

local function decode(t)
	local id, time = t:match("(.+)#(.+)")
	if time then
		return base64decode(id), base64decode(time)
	end
end


local user = {}    -- id -> {old_token, cur_token, destroy_timer, db_obj}

local commond = {}

function commond.create(id)
    local now = os.time()
    local expires_time = now + EXPIRES_TIME
    local t = base64encode(id).."#"..base64encode(now)
    local u = user[id]
    if u then
        local cancel = assert(u[3])
        cancel()
        u[1] = u[2]
        u[2] = t
        u[3] = timer.create(EXPIRES_TIME*100, function()
            u[1] = t
            u[2] = nil
            u[3] = nil
        end)

        u[4].token = t
        u[4].expires_time = expires_time
    else
        u = {nil, t}
        u[3] = timer.create(EXPIRES_TIME*100, function()
            u[1] = t
            u[2] = nil
            u[3] = nil
        end)
        u[4] = db.wind_token.miss_find_one {id = id}
        if u[4] then
            u[4].token = t
            u[4].expires_time = expires_time
        else
            u[4] = db.wind_token.miss_insert{id = id, token = t, expires_time = expires_time}
        end
        user[id] = u
    end
    return t
end

function commond.auth(t)
    local now = os.time()
    local id, time = decode(t)
    local u = id and user[id]
    if not u then
        return nil, AUTH_ERROR.invalid_token
    end

    if t == u[2] then       -- current token
        return id
    elseif t == u[1] then   -- old token
        if now - time <= EXPIRES_TIME then
            return id
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
            local u = {nil, token.token, nil, token}
            u[3] = timer.create(dt*100, function()
                u[1] = t
                u[2] = nil
                u[3] = nil
            end)
            user[token.id] = u
        end
    end
end

skynet.start(function() 
    load_token()
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = assert(commond[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)

-- end of token service
    end

    service_addr = service.new("token", token_service)
end)

return token