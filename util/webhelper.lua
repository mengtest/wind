local skynet = require "skynet"
local socket = require "skynet.socket"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local httpd = require "http.httpd"


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


local function start(id, handler, protocol)
    socket.start(id)
    local interface = gen_interface(protocol or "http", id)
    if interface.init then
        interface.init()
    end
    local ok, err
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(interface.read, 8192)
    if code then
        if code ~= 200 then
            response(id, interface.write, code)
            ok = false
            err = "code ~= 200"
        else
            local path, query = urllib.parse(url)

            if query then
                query = urllib.parse_query(query)
			end
						
			local function close (r)
				response(id, interface.write, code, r)
				socket.close(id)
				if interface.close then
					interface.close()
				end
			end
			return true, method, header, path, query, body, close
        end
    else
        ok = false
        err = (url == sockethelper.socket_error) and "socket closed" or url
    end
    socket.close(id)
    if interface.close then
        interface.close()
    end
    return ok, err
end


return start