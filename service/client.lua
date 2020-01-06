local skynet = require "skynet"
local socket = require "skynet.socket"




local function main()
    local fd = socket.open("127.0.0.1", 8888)
    print("client_fd:", fd)
    skynet.sleep(50)
    socket.write(fd, string.pack(">s2", "helloworld"))
    socket.close(fd)
end

skynet.start(main)