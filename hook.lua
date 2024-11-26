local gmod = gmod
local pairs = pairs
local setmetatable = setmetatable
local isstring = isstring
local isnumber = isnumber
local isbool = isbool
local isfunction = isfunction
local insert = table.insert
local IsValid = IsValid
local type = type
local ErrorNoHalt = ErrorNoHalt
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local print = print
local timer = timer
local file = file
local math = math

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
Version = "1.2.2"

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
	local new_event = {}
	do
		for i = 1, event[1] + 3 --[[hook_count + post_or_return_hook_index + post_hook_index]] do
			local v = event[i]
			-- this check because hook.Remove calls this without rearranging the event table
			-- so we have to make sure that we don't add nil values to the new event table
			if v ~= nil then
				insert(new_event, v)
			end
		end

		-- we subtract 4 because hook.Remove calls copy_event without subtracting the hook_count
		new_event[1] = event[1] - 4
		new_event[2] = post_or_return_hook_index(event)
		new_event[3] = post_hook_index(event)
	end

	-- we use proxies here just to make __index work
	-- https://stackoverflow.com/a/3122136
	local proxy_event = {}
	do
		for i = 1, event[1] + 3 --[[hook_count + post_or_return_hook_index + post_hook_index]] do
			proxy_event[i] = event[i]
			event[i] = nil
		end
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
			-- we substract 3 from key because first three elements in the table are [table_count, post_or_return_hook_index, post_hook_index]
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
			func = function(...)
				real_func(...)
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

local function internal_call(event_name, gm, ...)
	local event = events[event_name]
	if event ~= nil then
		local hook_count = event[1]
		local post_or_return_index = event[2]

		-- if there is a post hook, stop before it otherwise just use hook count
		local loop_end_index = post_or_return_index > 0 and post_or_return_index - 4 or hook_count

		for i = 4, loop_end_index, 4 do
			local func = event[i + 1]
			-- we check here for the function because the hook could have been removed while hook.Call was running
			if func then
				local a, b, c, d, e, f = func(...)
				if a ~= nil then
					return event[i] --[[name]], a, b, c, d, e, f
				end
			end
		end
	end

	if gm then
		local gm_func = gm[event_name]
		if gm_func then
			return gm, gm_func(gm, ...)
		end
	end
end

function Call(event_name, gm, ...)
	local event = events[event_name]

	local hook_name, a, b, c, d, e, f = internal_call(event_name, gm, ...)

	if not event then return a, b, c, d, e, f end

	local post_or_return_index = event[2]
	if post_or_return_index == 0 then return a, b, c, d, e, f end

	local hook_count = event[1]
	local post_index = event[3]

	local returned_values = {hook_name, a, b, c, d, e, f}

	if post_or_return_index > 0 then
		local loop_end_index = post_index > 0 and post_index - 4 or hook_count
		for i = post_or_return_index, loop_end_index, 4 do
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

local gamemode_cache
function Run(name, ...)
	-- AVOID HAVING ADDITIONAL C CALLS, SO SIMPLE HOOKS CAN BE EXTRA 2% FASTER
	if not gamemode_cache then
		gamemode_cache = gmod and gmod.GetGamemode() or nil
	end
	return Call(name, gamemode_cache, ...)
end

-- lots of testing cases are taken from meepen https://github.com/meepen/gmod-hooks-revamped/blob/master/hooksuite.lua
-- big thanks to him really for his great work
-- (when i was making the library i was testing lots of random cases and i never noted them down, there were lots of shady cases but unfortunately they are gone)

-- local assert = _GLOBAL.assert
-- local table = _GLOBAL.table
-- local tostring = _GLOBAL.tostring
-- local pcall = _GLOBAL.pcall
-- local error = _GLOBAL.error

-- local TEST = {}

-- -- this is to check if hooks order is by first to last or last to first

-- setmetatable(TEST, {
-- 	__call = function(self, func)
-- 		insert(self, func)
-- 	end
-- })

-- -- Basic add and call test
-- TEST(function(name)
-- 	local gm_table = {}
-- 	gm_table[name] = function(gm, ret)
-- 		return ret
-- 	end

-- 	local ran = false
-- 	Add(name, "1", function()
-- 		ran = true
-- 	end)

-- 	local ret = Call(name, gm_table, 1)

-- 	assert(ran == true, "hook.Call didn't run the hook")
-- 	assert(ret == 1, "hook.Call didn't run the gamemode function or returned the wrong value")
-- end)

-- -- Adding hooks with same priority
-- TEST(function(name)
-- 	local order = {}
-- 	for i = 1, 3 do
-- 		Add(name, tostring(i), function() table.insert(order, tostring(i)) end, NORMAL_PRIORITY)
-- 	end

-- 	Call(name, {})

-- 	assert(table.concat(order) == "123", "Hooks with the same priority did not execute in order of addition")
-- end)

-- -- Remove hook test
-- TEST(function(name)
-- 	local executed = {}
-- 	Add(name, "hook1", function() table.insert(executed, "hook1") end)
-- 	Add(name, "hook2", function() table.insert(executed, "hook2") end)

-- 	Remove(name, "hook1")
-- 	Call(name, {})

-- 	assert(not table.HasValue(executed, "hook1"), "Removed hook should not execute")
-- end)

-- -- Replace hook functionality
-- TEST(function(name)
-- 	local executed = false
-- 	Add(name, "hook", function() executed = true end)
-- 	Add(name, "hook", function() executed = false end)

-- 	Call(name, {})

-- 	assert(executed == false, "Hook should have its functionality replaced")
-- end)

-- -- Chain of hooks
-- TEST(function(name)
-- 	local order = {}
-- 	for i = 1, 5 do
-- 		Add(name, "hook" .. tostring(i), function() table.insert(order, "hook" .. tostring(i)) end)
-- 	end

-- 	Call(name, {})

-- 	assert(table.concat(order) == "hook1hook2hook3hook4hook5", "Complex chain of hooks did not execute correctly")
-- end)

-- -- Concurrent add/remove during call
-- TEST(function(name)
-- 	local dynamic_hook = function() Remove(name, "dynamic") end
-- 	Add(name, "static", function() Add(name, "dynamic", dynamic_hook) end)

-- 	Call(name, {})

-- 	assert( pcall(Call, name, {}), "Should be stable after concurrent add/remove during call")
-- end)

-- -- Nested hok calls
-- TEST(function(name)
-- 	local nested_called = false
-- 	Add(name, "outer", function() Call("nested", {}) end)
-- 	Add("nested", "inner", function() nested_called = true end)

-- 	Call(name, {})

-- 	assert(nested_called, "Nested hook calls should be handled correctly")
-- end)

-- -- Hooks with variable arguments
-- TEST(function(name)
-- 	local args_received = false
-- 	Add(name, "varargs", function(...) args_received = {...} end)

-- 	Call(name, {}, 1, 2, 3)

-- 	assert(#args_received == 3 and args_received[1] == 1 and args_received[2] == 2 and args_received[3] == 3, "Hooks should handle variable arguments correctly")
-- end)

-- -- Hook call with gamemode function and no hooks
-- TEST(function(name)
-- 	local gm_table = {}
-- 	gm_table[name] = function() return "gm_called" end

-- 	local ret = Call(name, gm_table)

-- 	assert(ret == "gm_called", "The gamemode function should run and return its value when no hooks are present")
-- end)


-- -- PreHook with return stopping execution
-- TEST(function(name)
-- 	local gm_table = {}
-- 	gm_table[name] = function() return "gm_not_called" end
-- 	local returnValue = nil
-- 	Add(name, "PreHookReturn", function() return "pre_returned" end, PRE_HOOK_RETURN)

-- 	returnValue = Call(name, gm_table)

-- 	assert(returnValue == "pre_returned", "Pre-hook with return should stop execution and return its value")
-- end)

-- -- Normal hook running with PostHook present
-- TEST(function(name)
-- 	local normal_hook_ran = false
-- 	local post_hood_ran = false
-- 	Add(name, "normalhook", function() normal_hook_ran = true end, NORMAL_HOOK)
-- 	Add(name, "posthook", function() post_hood_ran = true end, POST_HOOK)

-- 	Call(name, {})

-- 	assert(normal_hook_ran and post_hood_ran, "Both normal and posthooks should run")
-- end)

-- -- Post-Hook with return modifying overall return value
-- TEST(function(name)
-- 	local return_value = nil
-- 	Add(name, "normalhook", function() return "original_return" end, NORMAL_HOOK)
-- 	Add(name, "posthookreturn", function() return "post_modified" end, POST_HOOK_RETURN)

-- 	return_value = Call(name, {})

-- 	assert(return_value == "post_modified", "Post-hook with return should modify the overall return value")
-- end)

-- -- Post-Hook without return not modifying overall return value
-- TEST(function(name)
-- 	local return_value = nil
-- 	Add(name, "normalhook", function() return "original_return" end, NORMAL_HOOK)
-- 	Add(name, "posthook", function() end, POST_HOOK)

-- 	return_value = Call(name, {})

-- 	assert(return_value == "original_return", "Post-hook without return should not modify the overall return value")
-- end)

-- -- Post-Hok running after gamemode function
-- TEST(function(name)
-- 	local gm_table = {}
-- 	gm_table[name] = function() return "gm_called" end
-- 	local posthook_ran = false
-- 	Add(name, "postHook", function() posthook_ran = true end, POST_HOOK)

-- 	local return_value = Call(name, gm_table)

-- 	assert(posthook_ran and return_value == "gm_called", "Post-hook should run after gamemode function")
-- end)

-- -- Post-Hook modifying gamemode function return value
-- TEST(function(name)
-- 	local gm_table = {}
-- 	gm_table[name] = function() return "gm_called" end
-- 	Add(name, "postHookreturn", function() return "post_modified" end, POST_HOOK_RETURN)

-- 	local return_value = Call(name, gm_table)

-- 	assert(return_value == "post_modified", "Post-hook should modify the return value of the gamemode function")
-- end)

-- -- Hook remove during execution
-- TEST(function(name)
-- 	local hookran = false
-- 	local removing_hook = function() Remove(name, "dynamicHook") end
-- 	Add(name, "removing_hook", removing_hook, PRE_HOOK)
-- 	Add(name, "dynamicHook", function() hookran = true end, NORMAL_HOOK)

-- 	Call(name, {})

-- 	assert(not hookran, "Hook should not run after being removed")
-- end)

-- -- Test weird adding in calls
-- TEST(function(name)
-- 	local a, b, b2, c
-- 	Add(name, "a", function()
-- 		a = true
-- 		Remove(name, "a")
-- 		Add(name, "b", function()
-- 			b2 = true
-- 		end)
-- 	end)

-- 	Add(name, "c", function()
-- 		c = true
-- 	end)

-- 	Add(name, "b", function()
-- 		b = true
-- 	end)

-- 	Call(name)
-- 	assert(a == true and b == nil and b2 == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " b2: " .. tostring(b2) .. " c: " .. tostring(c))
-- 	a, b, b2, c = nil, nil, nil, nil
-- 	Call(name)
-- 	assert(a == nil and b == nil and b2 == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " b2: " .. tostring(b2) .. " c: " .. tostring(c))
-- end)

-- -- Test adding a hook inside hook.Call to make sure that the new added hook wont be called in the current hook.Call
-- -- gmod default behavior is wrong here, read https://github.com/Facepunch/garrysmod/pull/1642#issuecomment-601288451
-- TEST(function(name)
-- 	local a, b, c
-- 	Add(name, "a", function()
-- 		a = true
-- 		Add(name, "c", function()
-- 			c = true
-- 		end)
-- 	end)
-- 	Add(name, "b", function()
-- 		b = true
-- 	end)

-- 	Call(name)
-- 	assert(a == true and b == true and c == nil, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " c: " .. tostring(c))
-- 	a, b, c = nil, nil, nil
-- 	Call(name)
-- 	assert(a == true and b == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " c: " .. tostring(c))
-- end)

-- -- Test calling with no return values in normal hook, gm should run
-- TEST(function(name)
-- 	local gm_called, normal_called, post_called

-- 	local gm_table = {
-- 		[name] = function(gm)
-- 			gm_called = true
-- 		end,
-- 	}

-- 	Add(name, "NORMAL_HOOK", function()
-- 		normal_called = true
-- 	end)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_value)
-- 		assert(returned_value[1] == gm_table, "something is wrong")
-- 		post_called = true
-- 	end, POST_HOOK_RETURN)

-- 	assert(Call(name, gm_table) == nil and normal_called == true and post_called == true and gm_called == true, "something is wrong: normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
-- end)

-- -- Test calling with return values in normal hook, gm should not run
-- TEST(function(name)
-- 	local gm_called, normal_called, post_called

-- 	local gm_table = {
-- 		[name] = function(gm)
-- 			gm_called = true
-- 		end
-- 	}

-- 	Add(name, "NORMAL_HOOK", function()
-- 		normal_called = true
-- 		return "NORMAL_HOOK"
-- 	end)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_value)
-- 		assert(returned_value[1] == "NORMAL_HOOK", "something is wrong")
-- 		post_called = true
-- 	end, POST_HOOK_RETURN)

-- 	local returned = Call(name, gm_table)
-- 	assert(returned == "NORMAL_HOOK" and normal_called == true and post_called == true and gm_called == nil, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
-- end)

-- -- Test calling with no return values in normal hook, and gm returns values
-- TEST(function(name)
-- 	local gm_called, normal_called, post_called

-- 	local gm_table = {
-- 		[name] = function(gm)
-- 			gm_called = true
-- 			return "GM_RETURN"
-- 		end
-- 	}

-- 	Add(name, "NORMAL_HOOK", function()
-- 		normal_called = true
-- 	end)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_value)
-- 		assert(returned_value[1] == gm_table and returned_value[2] == "GM_RETURN", "something is wrong")
-- 		post_called = true
-- 	end, POST_HOOK_RETURN)

-- 	local returned = Call(name, gm_table)
-- 	assert(returned == "GM_RETURN" and normal_called == true and post_called == true and gm_called == true, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
-- end)

-- -- Test calling with post hook modifies normal hook return, gm shouldnt run
-- TEST(function(name)
-- 	local gm_called, normal_called, post_called

-- 	local gm_table = {
-- 		[name] = function(gm)
-- 			gm_called = true
-- 		end
-- 	}

-- 	Add(name, "NORMAL_HOOK", function()
-- 		normal_called = true
-- 		return "NORMAL_HOOK"
-- 	end)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_value)
-- 		assert(returned_value[1] == "NORMAL_HOOK", "something is wrong")
-- 		post_called = true
-- 		return "POST_HOOK_RETURN"
-- 	end, POST_HOOK_RETURN)

-- 	local returned = Call(name, gm_table)
-- 	assert(returned == "POST_HOOK_RETURN" and normal_called == true and post_called == true and gm_called == nil, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
-- end)

-- -- Test calling with post hook modifies gm function return
-- TEST(function(name)
-- 	local gm_called, normal_called, post_called

-- 	local gm_table = {
-- 		[name] = function(gm)
-- 			gm_called = true
-- 			return "GM_RETURN"
-- 		end
-- 	}

-- 	Add(name, "NORMAL_HOOK", function()
-- 		normal_called = true
-- 	end)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_value)
-- 		assert(returned_value[1] == gm_table and returned_value[2] == "GM_RETURN", "something is wrong")
-- 		post_called = true
-- 		return "POST_HOOK_RETURN"
-- 	end, POST_HOOK_RETURN)

-- 	local returned = Call(name, gm_table)
-- 	assert(returned == "POST_HOOK_RETURN" and normal_called == true and post_called == true and gm_called == true, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
-- end)

-- TEST(function(name)
-- 	local call_orders = {}
-- 	Add(name, "PRE_HOOK", function(arg1, arg2, arg3)
-- 		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "PRE_HOOK didn't get the right argument")
-- 		insert(call_orders, PRE_HOOK)
-- 	end, PRE_HOOK)

-- 	Add(name, "PRE_HOOK_RETURN", function(arg1, arg2, arg3)
-- 		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "PRE_HOOK_RETURN didn't get the right argument")
-- 		insert(call_orders, PRE_HOOK_RETURN)
-- 	end, PRE_HOOK_RETURN)

-- 	Add(name, "NORMAL_HOOK", function(arg1, arg2, arg3)
-- 		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "NORMAL_HOOK didn't get the right argument")
-- 		insert(call_orders, NORMAL_HOOK)
-- 		return "testing_returns"
-- 	end, NORMAL_HOOK)

-- 	Add(name, "POST_HOOK_RETURN", function(returned_values, arg1, arg2, arg3)
-- 		assert(returned_values[1] == "NORMAL_HOOK" and returned_values[2] == "testing_returns" and arg1 == 1 and arg2 == 2 and arg3 == 3, "POST_HOOK_RETURN didn't get the right argument")
-- 		insert(call_orders, POST_HOOK_RETURN)
-- 		return "testing_post_return"
-- 	end, POST_HOOK_RETURN)

-- 	Add(name, "POST_HOOK", function(returned_values, arg1, arg2, arg3)
-- 		assert(returned_values[1] == "POST_HOOK_RETURN" and returned_values[2] == "testing_post_return" and arg1 == 1 and arg2 == 2 and arg3 == 3, "POST_HOOK didn't get the right argument")
-- 		insert(call_orders, POST_HOOK)
-- 	end, POST_HOOK)

-- 	Call(name, nil, 1, 2, 3)

-- 	local expected_call_orders = {
-- 		PRE_HOOK,
-- 		PRE_HOOK_RETURN,
-- 		NORMAL_HOOK,
-- 		POST_HOOK_RETURN,
-- 		POST_HOOK,
-- 	}

-- 	for i = 1, #expected_call_orders do
-- 		if call_orders[i] ~= expected_call_orders[i] then
-- 			error("something is wrong, expected: " .. expected_call_orders[i][1] .. " got: " .. call_orders[i][1])
-- 		end
-- 	end
-- end)

-- TEST(function(name)
-- 	local entity = {
-- 		IsValid = function()
-- 			return true
-- 		end
-- 	}

-- 	Add(name, entity, function()
-- 		return true
-- 	end)

-- 	assert(Call(name, nil, 1) == true, "hook.Call didn't run the hook or returned the wrong value")
-- end)

-- TEST(function(name)
-- 	local called = 0
-- 	local entity = {
-- 		IsValid = function()
-- 			called = called + 1
-- 			if called <= 2 then
-- 				return true
-- 			end
-- 			return false
-- 		end
-- 	}

-- 	Add(name, entity, function()
-- 		return true
-- 	end)

-- 	assert(Call(name, nil, 1) == true, "hook.Call didn't run the hook or returned the wrong value")
-- 	assert(Call(name, nil, 1) == nil, "hook.Call entity was called even though it became invalid")
-- end)

-- TEST(function(name)
-- 	local entity = {
-- 		IsValid = function()
-- 			return true
-- 		end
-- 	}

-- 	local entity_call_count = 0
-- 	Add(name, entity, function()
-- 		entity_call_count = entity_call_count + 1
-- 	end)

-- 	local call_count = 0
-- 	Add(name, "1", function()
-- 		call_count = call_count + 1
-- 		return 1
-- 	end)

-- 	assert(Call(name, nil, 1) == 1, "hook.Call didn't run the hook or returned the wrong value")
-- 	assert(call_count == 1, "call count is wrong: " .. call_count)
-- 	assert(entity_call_count == 1, "entity call count is wrong: " .. entity_call_count)

-- 	call_count = 0
-- 	assert(Call(name, nil, 1) == 1, "hook.Call didn't run the hook or returned the wrong value")
-- 	assert(call_count == 1, "call count is wrong: " .. call_count)
-- end)

-- TEST(function(name)
-- 	Add(name, "1", function()
-- 		Remove(name, "1")
-- 	end)

-- 	Add(name, "2", function()
-- 		return 1
-- 	end, POST_HOOK_RETURN)

-- 	Call(name, nil, 1)
-- end)

-- TEST(function(name)
-- 	local called = false
--
-- 	Add(name, "1", function()
-- 		return 1
-- 	end, PRE_HOOK)
--
-- 	Add(name, "2", function()
-- 		called = true
-- 		return 2
-- 	end, PRE_HOOK)
--
-- 	Call(name)
-- 	assert(called == true, "hook.Call didn't run the hook or returned the wrong value")
-- end)
--
-- local test_name = "srlion_hook_test"
-- function Test()
-- 	print("Starting hook test...")
-- 	for i = 1, #TEST do
-- 		TEST[i](test_name .. tostring({}) .. tostring(i))
-- 	end
-- 	print("Hook test is done!")
-- end
