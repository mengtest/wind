local skynet = require "skynet"
local web = require "wind.web"
local db = require "wind.mongo"
local token = require "wind.token"
local uniqueid = require "wind.uniqueid"



web.post("/login", web.jsonhandle(function(self)
	local tel = assert(self.tel)
	local u = db.user.find_one({tel = tel}, {_id = false})
	if not u then
		local uid = uniqueid.gen("userid") 
		u = {
			tel = tel,

			-- user data
			id = uid,
			nickname = "玩家"..uid,
			gold = 0,
			diamond = 0
		}
		db.user.insert(u)
	end
	return {token = token.encode(u.id)}
end))


skynet.start(function()
	web.listen(9015)
end)