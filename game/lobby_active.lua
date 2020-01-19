local db = require "wind.mongo"
local conf = require "config.active"

local active

return function (me, request, command)
	function request:sign()
		if os.date("%Y%m%d") ~= os.date("%Y%m%d", active.sign_time) then
			local reward = conf.sign_reward
			me.gold = me.gold + reward.gold
			return {reward = reward}
		else
			return {err = GAME_ERROR.has_sign}
		end
	end

	active = db.active.miss_find_one_or_insert({pid = me.id}, {
		pid = me.id,
		sign_time = 0
	})
	dump("active:", active)
end