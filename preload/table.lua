function table.clone( obj )
    local function _copy( obj )
        if type(obj) ~= 'table' then
            return obj
        else
            local tmp = {}
            for k,v in pairs(obj) do
                tmp[_copy(k)] = _copy(v)
            end
            return setmetatable(tmp, getmetatable(obj))
        end
    end
    return _copy(obj)
end

function table.filter(t, filter)
	local filter_type = type(filter)
	if filter_type == "table" then
	    local new = {}
	    for k,v in pairs(t) do
	        if filter[k] == false then
	        
	        else
	            new[k] = v
	        end
	    end
	    return new
	else
		assert(filter_type == "function")
		local new = {}
		for k,v in pairs(t) do
			if filter(k, v) ~= false then
				new[k] = v
			end
		end
		return new
	end
end