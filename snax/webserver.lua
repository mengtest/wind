local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"


local function response(id, write, ...)
	local ok, err = httpd.write_response(write, ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end


local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd)
	if protocol == "http" then
		return {
			init = nil,
			close = nil,
			read = sockethelper.readfunc(fd),
			write = sockethelper.writefunc(fd),
		}
	elseif protocol == "https" then
		local tls = require "http.tlshelper"
		if not SSLCTX_SERVER then
			SSLCTX_SERVER = tls.newctx()
			-- gen cert and key
			-- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
			local certfile = skynet.getenv("certfile") or "./server-cert.pem"
			local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
			print(certfile, keyfile)
			SSLCTX_SERVER:set_cert(certfile, keyfile)
		end
		local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
		return {
			init = tls.init_responsefunc(fd, tls_ctx),
			close = tls.closefunc(tls_ctx),
			read = tls.readfunc(fd, tls_ctx),
			write = tls.writefunc(fd, tls_ctx),
		}
	else
		error(string.format("Invalid protocol: %s", protocol))
	end
end


local cross_origin = {
	["access-control-allow-origin"] = "*",
	["access-control-allow-methods"] = "GET, POST",
	["access-control-allow-headers"] = "x-requested-with,content-type",
	["content-type"] = "application/json"
}

local function launch_slave(request_handler, protocol)
    skynet.dispatch("lua", function (_,_,id)
        socket.start(id)
        local interface = gen_interface(protocol, id)
        if interface.init then
            interface.init()
        end
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(interface.read, 8192)
        if code then
            if code ~= 200 then
                response(id, interface.write, code)
            else
                local path, query = urllib.parse(url)

                if query then
                    query = urllib.parse_query(query)
                end

                local r = request_handler(method, header, path, query, body)
                response(id, interface.write, code, r, cross_origin)
            end
        else
            if url == sockethelper.socket_error then
                skynet.error("socket closed")
            else
                skynet.error(url)
            end
        end
        socket.close(id)
        if interface.close then
            interface.close()
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


local function webserver(conf)
    local name = "."..(conf.name or "web")
	skynet.start(function()
		local master = skynet.localname(name)
        if master then
            local request_handler = assert(conf.request_handler)
			launch_master = nil
			launch_slave(request_handler, conf.protocol or "http")
		else
			launch_slave = nil
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return webserver