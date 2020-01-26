local db = require "wind.mongo"
local lobby_active = require "game.lobby_active"

local function load_moudle(...)
	lobby_active(...)
end


return function (me, request, command)
	load_moudle(me, request, command)

	function request:base_info()
		return table.filter(me.self(), {_id = false})
	end

	function command.send2client(name, args)
	    agent.send_request(name, args)
	end
end