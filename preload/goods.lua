GOODS = {
	jipaiqi_tian = {id = "jipaiqi_tian", expiry_time = 0},
	jipaiqi_chang = {id = "jipaiqi_chang", num = 0},
	cj_jiabei = {id = "cj_jiabei", num = 0}
}

GOODS_GEN_ZERO = function(id, t)
	local goods = assert(GOODS[id])
	local new = table.clone(goods)
	if t then
		for k,v in pairs(t) do
			new[k] = v
		end
	end
	return new
end

GOODS_ADD = function (goods1, goods2)
	assert(goods1.id == goods2.id)
	if goods1.id == "jipaiqi_tian" then
		local now = os.time()
		if goods1.expiry_time >= now then
			goods1.expiry_time = goods1.expiry_time + goods2.num * 24*60*60
		else
			goods1.expiry_time = now + goods2.num * 24*60*60
		end
	else
		goods1.num = goods1.num + goods2.num
	end
	return goods1
end