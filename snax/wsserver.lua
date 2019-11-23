local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local websocket = require "http.websocket"


local function launch_slave(handle, protocol)
    skynet.dispatch("lua", function (_,_, id, addr)
        local ok, err = websocket.accept(id, handle, protocol, addr)
        if not ok then
            print(err)
        end
    end)
end


local function launch_master(conf)
    local instance = conf.instance or skynet.getenv "thread"
    local host = conf.host or "0.0.0.0"
    local port = assert(tonumber(conf.port))
    local slave = {}
    local balance = 1

	skynet.dispatch("lua", function(_,source,command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
    end)
    
	for i=1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("%s listen at : %s %d", conf.name or "web", host, port))
	local id = socket.listen(host, port)

    socket.start(id, function(id, addr)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
        skynet.send(s, "lua", id, addr)
    end)
end


local function wsserver(conf)
    local name = "."..(conf.name or "ws")
	skynet.start(function()
		local master = skynet.localname(name)
        if master then
            local handle = assert(conf.handle)
			launch_master = nil
			launch_slave(handle, conf.protocol or "ws")
		else
			launch_slave = nil
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return wsserver