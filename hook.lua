local gmod = gmod
local debug = debug
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local insert = table.insert

local stringMeta = getmetatable("")
local function isstring(value)
	return getmetatable(value) == stringMeta
end

local functionMeta = getmetatable(isstring) or {}
if not getmetatable(isstring) then
	debug.setmetatable(isstring, functionMeta)
end
local function isfunction(value)
	return getmetatable(value) == functionMeta
end

module("hook")

MONITOR_HIGH, HIGH, NORMAL, LOW, MONITOR_LOW = 1, 2, 3, 4, 5

local events = {}

local function find_hook(event, name)
	for i = 1, event.n, 4 do
		local _name = event[i]
		if _name and _name == name then
			return i
		end
	end
end

local function copy_event(event)
	local new_event = {}
	for i = 1, event.n do
		local v = event[i]
		if v then
			insert(new_event, v)
		end
	end
	new_event.n = #new_event
	setmetatable(event, {
		__index = function(_, key)
			local name = rawget(event, key - 1)
			if name and find_hook(new_event, name) then
				return rawget(event, key)
			end
		end
	})
	return new_event
end

--[[---------------------------------------------------------
	Name: Add
	Args: string hookName, any identifier, function func
	Desc: Add a hook to listen to the specified event.
-----------------------------------------------------------]]
function Add(event_name, name, func, priority)
	if not isstring(event_name) then return end
	if not isfunction(func) then return end
	if not name then return end

	local real_func = func
	if not isstring(name) then
		func = function(...)
			local isvalid = name.IsValid
			if isvalid and isvalid(name) then
				return real_func(name, ...)
			end

			Remove(event_name, name)
		end
	end

	if not priority then
		priority = NORMAL
	elseif priority < MONITOR_HIGH then
		priority = MONITOR_HIGH
	elseif priority > MONITOR_LOW then
		priority = MONITOR_LOW
	end

	local event = events[event_name]
	if not event then
		event = {
			n = 0,
		}
		events[event_name] = event
	end

	local pos
	if event then
		local _pos = find_hook(event, name)
		if _pos and event[_pos + 3] ~= priority then
			Remove(event_name, name)
		else
			pos = _pos
		end
	end

	event = events[event_name]

	if pos then
		event[pos + 1] = func
		event[pos + 2] = real_func
		return
	end

	if priority == MONITOR_LOW then
		local n = event.n
		event[n + 1] = name
		event[n + 2] = func
		event[n + 3] = real_func
		event[n + 4] = priority
	else
		local event_pos = 4
		for i = 4, event.n, 4 do
			local _priority = event[i]
			if priority < _priority then
				if i < event_pos then
					event_pos = i
				end
			elseif priority >= _priority then
				event_pos = i + 4
			end
		end
		insert(event, event_pos - 3, name)
		insert(event, event_pos - 2, func)
		insert(event, event_pos - 1, real_func)
		insert(event, event_pos, priority)
	end

	event.n = event.n + 4
end

--[[---------------------------------------------------------
	Name: Remove
	Args: string hookName, identifier
	Desc: Removes the hook with the given indentifier.
-----------------------------------------------------------]]
function Remove(event_name, name)
	local event = events[event_name]
	if not event then return end

	local pos = find_hook(event, name)
	if pos then
		event[pos] = nil --[[name]]
		event[pos + 1] = nil --[[func]]
		event[pos + 2] = nil --[[real_func]]
		event[pos + 3] = nil --[[priority]]
	end

	events[event_name] = copy_event(event)
end

--[[---------------------------------------------------------
	Name: GetTable
	Desc: Returns a table of all hooks.
-----------------------------------------------------------]]
function GetTable()
	local new_events = {}

	for event_name, event in pairs(events) do
		local hooks = {}
		for i = 1, event.n, 4 do
			local name = event[i]
			if name then
				hooks[name] = event[i + 2] --[[real_func]]
			end
		end
		new_events[event_name] = hooks
	end

	return new_events
end

--[[---------------------------------------------------------
	Name: Call
	Args: string hookName, table gamemodeTable, vararg args
	Desc: Calls hooks associated with the hook name.
-----------------------------------------------------------]]
function Call(event_name, gm, ...)
	local event = events[event_name]
	if event then
		for i = 2, event.n, 4 do
			local func = event[i]
			if func then
				local a, b, c, d, e, f = func(...)
				if a ~= nil then
					return a, b, c, d, e, f
				end
			end
		end
	end

	--
	-- Call the gamemode function
	--
	if not gm then return end

	local GamemodeFunction = gm[event_name]
	if not GamemodeFunction then return end

	return GamemodeFunction(gm, ...)
end

--[[---------------------------------------------------------
	Name: Run
	Args: string hookName, vararg args
	Desc: Calls hooks associated with the hook name.
-----------------------------------------------------------]]
function Run(name, ...)
	return Call(name, gmod and gmod.GetGamemode() or nil, ...)
end