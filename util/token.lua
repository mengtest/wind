local crypt = require "skynet.crypt"


local token = {}


function token.encode(id, time)
    return crypt.base64encode(id)..'#'..crypt.base64encode(time)
end

function token.decode(t)
    local id, time = t:match("(%d+)#(%d+)")
    if id and time then
        return base64decode(id), tonumber(crypt.base64decode(time))
    end
end


return token