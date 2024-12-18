local gmod = gmod
local pairs = pairs
local setmetatable = setmetatable
local isstring = isstring
local isnumber = isnumber
local isbool = isbool
local isfunction = isfunction
local insert = table.insert
local type = type
local ErrorNoHalt = ErrorNoHalt
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local print = print
local timer = timer
local file = file
local math = math
local GProtectedCall = ProtectedCall

--[[
	lots of comments here are so long, just so i can remember why i did something and why i didnt do something else
	because when i try to modify a single thing, something breaks and i dont notice it, so i try to remind myself as much as possible
]]

do
	-- this is for addons who think every server only has ulx and supplies numbers for priorities instead of using the constants
	HOOK_MONITOR_HIGH = -2
	HOOK_HIGH = -1
	HOOK_NORMAL = 0
	HOOK_LOW = 1
	HOOK_MONITOR_LOW = 2

	PRE_HOOK = {-4}
	PRE_HOOK_RETURN = {-3}
	NORMAL_HOOK = {0}
	POST_HOOK_RETURN = {3}
	POST_HOOK = {4}
end

local PRE_HOOK = PRE_HOOK
local PRE_HOOK_RETURN = PRE_HOOK_RETURN
local NORMAL_HOOK = NORMAL_HOOK
local POST_HOOK_RETURN = POST_HOOK_RETURN
local POST_HOOK = POST_HOOK

local _GLOBAL = _G

module("hook")

local events = {}

do
	-- ulx/ulib support
	if file.Exists("ulib/shared/hook.lua", "LUA") then
		local old_include = _GLOBAL.include
		function _GLOBAL.include(f, ...)
			if f == "ulib/shared/hook.lua" then
				timer.Simple(0, function()
					print("Srlion Hook Library: Stopped ULX/ULib from loading it's hook library!")
				end)
				_GLOBAL.include = old_include
				return
			end
			return old_include(f, ...)
		end

		function GetULibTable()
			local new_events = {}

			for event_name, event in pairs(events) do
				local hooks = {[-2] = {}, [-1] = {}, [0] = {}, [1] = {}, [2] = {}}
				-- event starts with 4 because event[1] is the number of hooks in the event table, ...etc
				for i = 4, event[1] --[[hook_count]], 4 do
					local name = event[i]
					if name then
						local priority = event[i + 3]
						priority = math.Clamp(priority, -2, 2) -- just to make sure it's in the range
						hooks[priority][name] = event[i + 2] --[[real_func]]
					end
				end
				new_events[event_name] = hooks
			end

			local monitor_ulib_events = {}
			setmetatable(monitor_ulib_events, {
				__newindex = function(_, key, value)
					ErrorNoHaltWithStack("An addon is trying to modify ULib Table directly, use this trace to find the addon and fix it!")
					new_events[key] = value
				end,
				__index = function(_, key)
					return new_events[key]
				end
			})

			return monitor_ulib_events
		end
	end

	-- bloated hooks warning
	if file.Exists("dlib/modules/hook.lua", "LUA") then
		timer.Simple(0, function()
			ErrorNoHalt("Srlion Hook Library: DLib is installed, you should remove the bloated addon!\n")
			ErrorNoHalt("Srlion Hook Library: DLIB is also slower than default hook library, check github.com/srlion/Hook-Library for more info! THIS MEANS IT MAKES YOUR SERVER SLOWER!\n")
		end)
	end
end

local main_priorities = {
	[PRE_HOOK] = true,
	[PRE_HOOK_RETURN] = true,
	[NORMAL_HOOK] = true,
	[POST_HOOK_RETURN] = true,
	[POST_HOOK] = true
}

Author = "Srlion"
Version = "1.2.3"

--[=[
	events[event_name] = {
		1 => 20 (hook_count)
			this is the number of hooks in the event table, doesn't count itself nor post_or_return_hook_index
		2 => 16 (post_or_return_hook_index)
			this is the index of the first post(_return) hook in the event table
		3 => 20 (post_hook_index)
			this is the index of the first post hook in the event table

		4 =>	a (name)
		5 =>	function: 0xf (func)
		6 =>	function: 0xf (real_func)
		7 =>	0 (priority)

		8 =>	c
		9 =>	function: 0xf
		10 =>	function: 0xf
		11 =>	0

		12 =>	b
		13 =>	function: 0xf
		14 =>	function: 0xf
		15 =>	0

		16 =>	z
		17 =>	function: 0xf
		18 =>	function: 0xf
		19 =>	1

		20 =>	t
		21 =>	function: 0xf
		22 =>	function: 0xf
		23 =>	2
	}
]=]

local function find_hook(event, name)
	for i = 4, event[1] --[[hook_count]], 4 do
		local hook_name = event[i]
		if hook_name ~= nil and hook_name == name then
			return i
		end
	end
end

-- this is used to find the index of the first post(_return) hook in the event table
local function post_or_return_hook_index(event)
	for i = 4, event[1] --[[hook_count]], 4 do
		local priority = event[i + 3]
		if priority == POST_HOOK[1] or priority == POST_HOOK_RETURN[1] then
			return i
		end
	end
	return 0
end

local function post_hook_index(event)
	for i = 4, event[1] --[[hook_count]], 4 do
		local priority = event[i + 3]
		if priority == POST_HOOK[1] then
			return i
		end
	end
	return 0
end

--[[
	we are making a new event table so we don't mess up anything when
	adding/removing hooks while hook.Call is running, this is how it works:

	1- When (adding/removing a hook)/(editing a hook priority), we create a new event table to avoid messing up hook.Call call order if it's running,
	and the old event table will be shadowed and can only be accessed from "hook.Call" if it's running
	2- We make old event table have __index method to make sure if any hook got removed/edited we (stop it from running)/(run the new function)
]]
local function copy_event(event, event_name)
	-- we use proxies here just to make __index work
	-- https://stackoverflow.com/a/3122136
	local proxy_event = {}
	local new_event = {}
	do
		local count = event[1]
		local porhi, phi

		local j = 1
		for i = 1, count + 3 --[[hook_count + post_or_return_hook_index + post_hook_index]] do
			local v = event[i]
			proxy_event[i] = v
			-- this check because hook.Remove calls this without rearranging the event table
			-- so we have to make sure that we don't add nil values to the new event table
			if v ~= nil then
				if i >= 7 --[[if i is 4 then phi and porhi will be invalid]] and i % 4 == 0 then
					if not porhi and (v == POST_HOOK[1] or v == POST_HOOK_RETURN[1]) then
						porhi = i - 3 --[[name]]
					end
					if not phi and v == POST_HOOK[1] then
						phi = i - 3 --[[name]]
					end
				end
				new_event[j] = v
				j = j + 1
			end
			event[i] = nil
		end

		-- we subtract 4 because hook.Remove calls copy_event without subtracting the hook_count
		new_event[1] = count - 4
		new_event[2] = porhi or 0
		new_event[3] = phi or 0
	end

	-- REMOVE THIS COMMENT BEFORE PUSLIHING (THIS IS JUST A REMINDER TO FIND A NEW WAY TO DO THIS HACKY WAY)
	-- NEXT GMOD UPDATE REMOVES setmetatable (CONFIRMED BY GARY)
	setmetatable(event, {
		__index = function(_, key)
			if key == 1 then -- first element is the number of hooks in the event table
				return proxy_event[1]
			elseif key == 2 then -- second element is the index of the first post hook in the event table
				return proxy_event[2]
			elseif key == 3 then
				return proxy_event[3]
			end

			-- Maps the key to a 1-4 range for 'name', 'func', 'real_func', 'priority'.
			-- we subtract 3 from key because first three elements in the table are [table_count, post_or_return_hook_index, post_hook_index]
			local relative_index = ((key - 3) - 1) % 4 + 1
			local name_index = key - (relative_index - 1)

			-- we need to get the name from proxy table so we can do checks on newest table, eg. if hook was removed or priority changed
			local name = proxy_event[name_index]
			if not name then return end

			-- this is the newest event table that we check from if hook was removed or priority changed
			local newest_event = events[event_name]

			-- if hook got removed from latest table then don't run it
			local pos = find_hook(newest_event, name)
			if not pos then return end

			-- if hook priority changed in newest table then it should be treated as a new added hook (like it was just added inside the hook.Call), don't run it
			if newest_event[pos + 3 --[[priority]]] ~= proxy_event[name_index + 3 --[[priority]]] then return end

			-- we return from newest table because it could have been updated
			return newest_event[pos + (relative_index - 1)]

			--[=[
				(relative_index - 1) will be one of '1:name' '2:func' '3:real_func' '4:priority'
				pos will be (name) position in newest table, eg.

				pos = 3 (name), relative_index = 2 (func)
					- it will be 3 + (2 - 1) = 4 which is the position for function in the newest table

				pos = 7 (name), relative_index = 4 (priority)
					- it will be 7 + (4 - 1) = 10 which is the position for priority in the newest table

				you can check an example of how hook tables look like at the beginning
			]=]
		end
	})

	return new_event
end

function Remove(event_name, name)
	if not isstring(event_name) then ErrorNoHaltWithStack("bad argument #1 to 'Remove' (string expected, got " .. type(event_name) .. ")") return end

	local notValid = isnumber(name) or isbool(name) or isfunction(name) or not name.IsValid
	if not isstring(name) and notValid then ErrorNoHaltWithStack("bad argument #2 to 'Remove' (string expected, got " .. type(name) .. ")") return end

	local event = events[event_name]
	if not event then return end

	local pos = find_hook(event, name)
	if pos then
		event[pos] = nil --[[name]]
		event[pos + 1] = nil --[[func]]
		event[pos + 2] = nil --[[real_func]]
		event[pos + 3] = nil --[[priority]]
		events[event_name] = copy_event(event, event_name)
	end
end

function Add(event_name, name, func, priority)
	if not isstring(event_name) then ErrorNoHaltWithStack("bad argument #1 to 'Add' (string expected, got " .. type(event_name) .. ")") return end
	if not isfunction(func) then ErrorNoHaltWithStack("bad argument #3 to 'Add' (function expected, got " .. type(func) .. ")") return end

	local notValid = name == nil or isnumber(name) or isbool(name) or isfunction(name) or not name.IsValid
	if not isstring(name) and notValid then ErrorNoHaltWithStack("bad argument #2 to 'Add' (string expected, got " .. type(name) .. ")") return end

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

	if isnumber(priority) then
		priority = math.floor(priority)
		if priority < -2 then priority = -2 end
		if priority > 2 then priority = 2 end
	elseif main_priorities[priority] then
		if priority == PRE_HOOK then
			local old_func = func
			func = function(...)
				old_func(...)
			end
		end
		priority = priority[1]
	else
		if priority ~= nil then
			ErrorNoHaltWithStack("bad argument #4 to 'Add' (priority expected, got " .. type(priority) .. ")")
		end
		-- we probably don't want to stop the function here because it's not a critical error
		priority = NORMAL_HOOK[1]
	end

	local event = events[event_name]
	if not event then
		event = {0 --[[hook_count]], 0 --[[post_or_return_hook_index]], 0 --[[post_hook_index]]}
		events[event_name] = event
	end

	local hook_pos
	if event then
		local pos = find_hook(event, name)
		-- if hook exists and priority changed then remove the old one because it has to be treated as a new hook
		if pos and event[pos + 3] ~= priority then
			Remove(event_name, name)
		else
			-- just update the hook here because nothing changed but the function
			hook_pos = pos
		end
	end

	-- the event table could have been changed the check above, check Remove function
	event = events[event_name]

	-- this just updates the hook if it exists and nothing changed but the function
	if hook_pos then
		event[hook_pos + 1] = func
		event[hook_pos + 2] = real_func
		return
	end

	local hook_count = event[1]
	local insert_pos = (hook_count + 3 --[[hook_count + post_or_return_hook_index + post_hook_index]]) + 1  -- default position is at the end

	for i = 4, hook_count, 4 do
		if event[i + 3 --[[priority]]] > priority then  -- the priority is at the fourth position in each group of four
			insert_pos = i
			break
		end
	end

	insert(event, insert_pos, name)
	insert(event, insert_pos + 1, func)
	insert(event, insert_pos + 2, real_func)
	insert(event, insert_pos + 3, priority)

	event[1] = hook_count + 4
	event[2] = post_or_return_hook_index(event)
	event[3] = post_hook_index(event)
end

function GetTable()
	local new_events = {}

	for event_name, event in pairs(events) do
		local hooks = {}

		-- event starts with 4 because event[1] is the number of hooks in the event table, ...etc
		for i = 4, event[1] --[[hook_count]], 4 do
			local name = event[i]
			if name then
				hooks[name] = event[i + 2] --[[real_func]]
			end
		end
		new_events[event_name] = hooks
	end

	return new_events
end

local gamemode_cache
function Run(name, ...)
	-- AVOID HAVING ADDITIONAL C CALLS, SO SIMPLE HOOKS CAN BE EXTRA 2% FASTER
	if not gamemode_cache then
		gamemode_cache = gmod and gmod.GetGamemode() or nil
	end
	return Call(name, gamemode_cache, ...)
end

function ProtectedRun(name, ...)
	if not gamemode_cache then
		gamemode_cache = gmod and gmod.GetGamemode() or nil
	end
	return ProtectedCall(name, gamemode_cache, ...)
end

function Call(event_name, gm, ...)
	local event = events[event_name]
	if not event then -- fast path
		if not gm then return end
		local gm_func = gm[event_name]
		if not gm_func then return end
		return gm_func(gm, ...)
	end

	local hook_count = event[1]
	local post_or_return_index = event[2]
	local hook_name, a, b, c, d, e, f; do
		-- if there is a post hook, stop before it otherwise just use hook count
		local loop_end_index = post_or_return_index > 0 and post_or_return_index - 4 or hook_count

		for i = 4, loop_end_index, 4 do
			local func = event[i + 1]
			-- we check here for the function because the hook could have been removed while hook.Call was running
			if func then
				-- this is a trick that gives a small boost by avoiding escaping the loop
				local a2, b2, c2, d2, e2, f2 = func(...)
				if a2 ~= nil then
					hook_name, a, b, c, d, e, f = event[i] --[[name]], a2, b2, c2, d2, e2, f2
					break
				end
			end
		end

		if not hook_name and gm then
			local gm_func = gm[event_name]
			if gm_func then
				hook_name, a, b, c, d, e, f = gm, gm_func(gm, ...)
			end
		end
	end

	if post_or_return_index < 1 then return a, b, c, d, e, f end

	local post_index = event[3]

	local returned_values = {hook_name, a, b, c, d, e, f}

	for i = post_or_return_index, post_index > 0 and post_index - 4 or hook_count --[[loop_end_index]], 4 do
		local func = event[i + 1]
		if func then
			local new_a, new_b, new_c, new_d, new_e, new_f = func(returned_values, ...)
			if new_a ~= nil then
				a, b, c, d, e, f = new_a, new_b, new_c, new_d, new_e, new_f
				returned_values[1] = event[i] --[[name]]
				returned_values[2] = new_a
				returned_values[3] = new_b
				returned_values[4] = new_c
				returned_values[5] = new_d
				returned_values[6] = new_e
				returned_values[7] = new_f
				break
			end
		end
	end

	if post_index > 0 then
		for i = post_index, hook_count, 4 do
			local func = event[i + 1]
			if func then
				func(returned_values, ...)
			end
		end
	end

	return a, b, c, d, e, f
end

function ProtectedCall(event_name, gm, ...)
	local event = events[event_name]

	local hook_count = event[1]
	local post_or_return_index = event[2]
	do
		local loop_end_index = post_or_return_index > 0 and post_or_return_index - 4 or hook_count
		for i = 4, loop_end_index, 4 do
			local func = event[i + 1]
			if func then
				GProtectedCall(func, ...)
			end
		end

		if gm then
			local gm_func = gm[event_name]
			if gm_func then
				GProtectedCall(gm_func, gm, ...)
			end
		end
	end

	if post_or_return_index < 1 then return end

	local returned_values = {nil, nil, nil, nil, nil, nil, nil}

	local post_index = event[3]

	for i = post_or_return_index, post_index > 0 and post_index - 4 or hook_count --[[loop_end_index]], 4 do
		local func = event[i + 1]
		if func then
			GProtectedCall(func, returned_values, ...)
		end
	end

	if post_index > 0 then
		for i = post_index, hook_count, 4 do
			local func = event[i + 1]
			if func then
				GProtectedCall(func, returned_values, ...)
			end
		end
	end
end
