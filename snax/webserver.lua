local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cjson = require "cjson"

local function launch_slave(conf)
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
    
    local function unpack_body(body)
        local data = cjson.decode(body)
        local cmd = assert(data[1])
        local args = data[2]
        if args then
            assert(type(args) == "table")
        end
        return cmd, args
    end
    
    local function do_request(cmd, args, request)
        local f = assert(request[cmd], "invalid cmd:"..tostring(cmd))
        local r = f(args)
        assert(type(r) == "table", "invalid result, cmd:"..tostring(cmd))
        return cjson.encode(r)
    end

    -- code here
    local commond = assert(conf.commond)
    local request = assert(conf.request)
    local protocol = conf.protocol or "http"
    assert(protocol == "http" or protocol == "https")

    local function accept(id)
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
                if method == "GET" then
                    response(id, interface.write, 405)
                else
                    local ok, cmd, args = pcall(unpack_body, body)
                    if ok then
                        local ok, result = pcall(do_request, cmd, args, request)
                        if ok then
                            response(id, interface.write, code, result, cross_origin)
                        else
                            skynet.error(result)
                            response(id, interface.write, 500, result)
                        end
                    else
                        response(id, interface.write, 400)
                    end
                end
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
    end

    skynet.dispatch("lua", function (_,_, id, ...)
        if type(id) == "number" then
            accept(id)
        else
            local cmd = id
            local f = assert(commond[cmd], cmd)
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end


local function launch_master(conf)
    local instance = conf.instance or skynet.getenv "thread"
    local host = conf.host or "0.0.0.0"
    local port = assert(tonumber(conf.port))
    local slave = {}
    local balance = 1
    
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
			launch_master = nil
			launch_slave(conf)
		else
			launch_slave = nil
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return webserver