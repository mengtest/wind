function table.filter(t, filter)
    local new = {}
    for k,v in pairs(t) do
        if filter[k] == false then
        
        else
            new[k] = v
        end
    end
    return new
end