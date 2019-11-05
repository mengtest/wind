local skynet = require "skynet"
local timer = require "timer"


local function main()


local function on_end()
    print("END")
end

local c
c = timer.create(100, function(count)
    print("TICK", count, skynet.now())
    -- if count == 5 then c() end
end, 3, on_end)





end


skynet.start(main)