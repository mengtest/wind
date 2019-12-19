local skynet = require "skynet"
local c = require "skynet.core"

local db = {}

local odispatch = skynet.dispatch_message

local unpack = c.unpack
local pack = c.pack
local send = c.send


function skynet.dispatch_message(prototype, msg, sz, session, source)
	if prototype == 10 then	-- 10 是 lua 消息，这里直接对这类消息进行解析。
		local key, value = unpack(msg, sz)
		if value then
			local v = db[key]
			db[key] = value
			send(source, 1, session, pack(v))
		else
            send(source, 1, session, pack(db[key])) -- 1 是回应消息，此处相当于 skynet.ret 。
		end
	else
		return odispatch(prototype, msg, sz, session, source)
	end
end

skynet.start(function() end)