local db = require "wind.mongo"
local crypt = require "skynet.crypt"

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode


local function token_encode(pid, time)
	return base64encode(pid).."#"..base64encode(time)
end

local function token_decode(t)
	local pid, time = t:match("(.+)#(.+)")
	if time then
		return base64decode(pid), base64decode(time)
	end
end

local function token_auth(t)
    local pid, time = token_decode(t)
    if time then
        local u = db.user.find_one({id = pid})
        if u and u.token == t then
            if os.time() - time <= 15*60 then
                return true, u
            end
        end
    end
    return false
end

return {
	encode = token_encode,
	decode = token_decode,
	auth = token_auth
}