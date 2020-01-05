local hooks = {}

local Call = function(event, gm, ...)
	local hook = hooks[event]
	if hook then
		local i, n, func = 2, hook.n, nil
		if i <= n then
			::loop:: -- https://github.com/Facepunch/garrysmod/pull/1508#issuecomment-398231260
			func = hook[i --[[func]]]
			if func then
				local a, b, c, d, e, f = func(...)
				if a ~= nil then
					return a, b, c, d, e, f
				end
				i = i + 3
				if i <= n then
					goto loop
				end
			else
				--
				-- hook got removed, we gotta do some work!
				--

				if hook.n ~= n then
					--
					-- a new hook was added while the hook is running, we will replace it with the removed one and continue without calling it
					--

					local n_2 = hook.n
					--[[name]] --[[func]] --[[real_func]]
					hook[i - 1], hook[i], hook[i + 1] = hook[n_2 - 2], hook[n_2 - 1], hook[n_2]
					hook[n_2 - 2], hook[n_2 - 1], hook[n_2] = nil, nil, nil
					i = i + 3
				else
					--
					-- replace the removed hook with the last hook in the table and repeat the loop, if it's the last one then it's gonna be nil and the loop will stop
					--

					--[[name]] --[[func]] --[[real_func]]
					hook[i - 1], hook[i], hook[i + 1] = hook[n - 2], hook[n - 1], hook[n]
					hook[n - 2], hook[n - 1], hook[n] = nil, nil, nil
					n = n - 3
				end

				hook.n = hook.n - 3

				if i <= n then
					goto loop
				end
			end
		end
	end

	if gm then
		local gm_func = gm[event]
		if gm_func then
			return gm_func(gm, ...)
		end
	end
end

local gmod = gmod
local Run = function(name, ...)
	return Call(name, gmod and gmod.GetGamemode() or nil, ...)
end

local Hook = {}
do
	local hook_methods = {}
	local hook_meta = {__index = hook_methods}

	function Hook.new(event)
		local hook = setmetatable({}, hook_meta)
		hooks[event] = hook
		return hook
	end

	--
	-- it's efficient to store it like this so we don't have to index 2 tables in hook.Call: hook[i + 1] > hook[i]["func"]
	-- but I could be wrong and idc
	--
	function hook_methods:add(name, func, real_func)
		local n = self.n or 0

		for i = 1, n, 3 do
			if self[i --[[name]]] == name then
				self[i + 1 --[[func]]] = func
				self[i + 2 --[[real_func]]] = real_func
				return
			end
		end

		self[n + 1 --[[name]]] = name
		self[n + 2 --[[func]]] = func
		self[n + 3 --[[real_func]]] = real_func

		self.n = n + 3
	end

	function hook_methods:remove(name)
		for i = 1, self.n, 3 do
			if self[i --[[name]]] == name then
				self[i --[[name]]] = nil
				self[i + 1 --[[func]]] = nil
				self[i + 2 --[[real_func]]] = nil
				break
			end
		end
	end
end

local IsValid = IsValid
local Add = function(event, name, func)
	if not isstring(event) or not isfunction(func) then return end
	local hook = hooks[event] or Hook.new(event)
	local real_func = func
	if not isstring(name) then
		--
		-- took this idea (which is really great) from https://github.com/meepen/gmod-hooks-revamped/blob/486e9672762f8901d83c52794145955f01b93431/newhook.lua#L83
		--
		func = function(...)
			if IsValid(name) then
				return real_func(name, ...)
			else
				hook:remove(name)
			end
		end
	end
	hook:add(name, func, real_func)
end

local Remove = function(event, name)
	if isstring(event) then
		local hook = hooks[event]
		if hook then
			hook:remove(name)
		end
	end
end

local GetTable = function()
	local new_hooks = {}
	for event_name, event_table in pairs(hooks) do
		local event = {}
		for i = 1, event_table.n, 3 do
			local name = event_table[i --[[name]]]
			if name then
				event[name] = event_table[i + 2 --[[real_func]]]
			end
		end
		new_hooks[event_name] = event
	end
	return new_hooks
end

hook = {
	GetTable = GetTable,
	Add = Add,
	Remove = Remove,
	Call = Call,
	Run = Run,
	Author = "Srlion"
}
