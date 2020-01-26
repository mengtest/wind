local db = require "wind.mongo"
local conf = require "config.active"

local active

return function (me, request, command)

	function request:active()
		return table.filter(active, {_id = false})
	end
	--
	-- 每日签到
	--
	function request:sign()
		local now = os.time()
		local today = os.date("%Y%m%d", now)
		if today ~= os.date("%Y%m%d", active.sign_time) then
			local rewards = conf.sign_rewards
			active.sign_time = now
			me.add_rewards(rewards)
			return {rewards = rewards}
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