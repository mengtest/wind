local skynet = require "skynet"
local snax = require "skynet.snax"
local timer = require "timer"


local function main()

    snax.newservice("webserver", {
        port = 9005,
        worker = "web-worker"
    })


end


skynet.start(main)