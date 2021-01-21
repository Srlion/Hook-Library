local gmod = gmod
local pairs = pairs
local isstring = isstring
local isfunction = isfunction
local remove = table.remove

local empty_func = function() end

local to_remove = {}

timer.Create("SrlionHookLibrary", 5, 0, function()
	for i = #to_remove, 1, -1 do
		local v = to_remove[i]
		local event = v.event

		local pos = event.data[v.name].pos
		for _, hook in pairs(event.data) do
			if (hook.pos > pos) then
				hook.pos = hook.pos - 1
			end
		end
		remove(event, pos)

		event.n = event.n - 1
		event.data[v.name] = nil

		to_remove[i] = nil
	end
end)

module("hook")

local events = {}

function Add(event_name, name, func)
	if not isstring(event_name) then return end
	if not isfunction(func) then return end
	if not name then return end

	local real_func = func
	if not isstring(name) then
		-- big thanks to meepen https://github.com/meepen/gmod-hooks-revamped/blob/486e9672762f8901d83c52794145955f01b93431/newhook.lua#L83
		func = function(...)
			local isvalid = name.IsValid
			if isvalid and isvalid(name) then
				return real_func(name, ...)
			end

			Remove(event_name, name)
		end
	end

	local event = events[event_name]
	if not event then
		event = {
			data = {},
			n = 0
		}
		events[event_name] = event
	end

	local hook = event.data[name]
	if hook then
		if hook.removed then
			remove(to_remove, hook.removed)
			hook.removed = nil
		end

		event[hook.pos] = func
		hook.real_func = real_func

		return
	end

	event.n = event.n + 1

	hook = {
		real_func = real_func,
		pos = event.n
	}

	event[event.n] = func
	event.data[name] = hook
end

function Remove(event_name, name)
	local event = events[event_name]
	if not event then return end

	local hook = event.data[name]
	if not hook then return end

	if hook.removed then return end

	hook.real_func = nil

	to_remove[#to_remove + 1] = {
		event = event,
		name = name,
	}
	hook.removed = #to_remove

	event[hook.pos] = empty_func
end

function GetTable()
	local new_events = {}

	for event_name, event in pairs(events) do
		local hooks = {}

		for name, hook in pairs(event.data) do
			hooks[name] = hook.real_func
		end

		new_events[event_name] = hooks
	end

	return new_events
end

function Call(event_name, gm, ...)
	local event = events[event_name]
	if event then
		for i = 1, event.n do
			local a, b, c, d, e, f = event[i](...)
			if a ~= nil then
				return a, b, c, d, e, f
			end
		end
	end

	--
	-- Call the gamemode function
	--
	if not gm then return end

	local gm_func = gm[event_name]
	if not gm_func then return end

	return gm_func(gm, ...)
end

function Run(name, ...)
	return Call(name, gmod and gmod.GetGamemode() or nil, ...)
end