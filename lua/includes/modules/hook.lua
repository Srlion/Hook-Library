local gmod = gmod
local math = math
local table = table
local file = file
local timer = timer
local pairs = pairs
local setmetatable = setmetatable
local isstring = isstring
local isnumber = isnumber
local isbool = isbool
local isfunction = isfunction
local type = type
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local ErrorNoHalt = ErrorNoHalt
local print = print
local GProtectedCall = ProtectedCall
local tostring = tostring
local error = error

local _GLOBAL = _G

local EMPTY_FUNC = function() end

do
	-- this is for addons that think every server only has ulx and supplies numbers for priorities instead of using the constants
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

local NORMAL_PRIORITIES_ORDER = {
	[PRE_HOOK] = 1, [HOOK_MONITOR_HIGH] = 2, [PRE_HOOK_RETURN] = 3, [HOOK_HIGH] = 4,
	[NORMAL_HOOK] = 5, [HOOK_NORMAL] = 5, [HOOK_LOW] = 6, [HOOK_MONITOR_LOW] = 7,
	-- Special hooks, they don't use an order
}

local EVENTS_LISTS = {
	-- Special hooks
	[POST_HOOK_RETURN] = 2,
	[POST_HOOK] = 3,
}
for k, v in pairs(NORMAL_PRIORITIES_ORDER) do
	EVENTS_LISTS[k] = 1
end

local MAIN_PRIORITIES = {[PRE_HOOK] = true, [PRE_HOOK_RETURN] = true, [NORMAL_HOOK] = true, [POST_HOOK_RETURN] = true, [POST_HOOK] = true}

local PRIORITIES_NAMES = {
	[PRE_HOOK] = "PRE_HOOK", [HOOK_MONITOR_HIGH] = "HOOK_MONITOR_HIGH", [PRE_HOOK_RETURN] = "PRE_HOOK_RETURN",
	[HOOK_HIGH] = "HOOK_HIGH", [NORMAL_HOOK] = "NORMAL_HOOK", [HOOK_NORMAL] = "HOOK_NORMAL",
	[HOOK_LOW] = "HOOK_LOW", [HOOK_MONITOR_LOW] = "HOOK_MONITOR_LOW", [POST_HOOK_RETURN] = "POST_HOOK_RETURN", [POST_HOOK] = "POST_HOOK",
}

module("hook")

Author = "Srlion"
Version = "3.0.0"

local events = {}

local node_meta = {
	-- will only be called to retrieve the function
	__index = function(node, key)
		if key ~= 0 then -- this should never happen
			error("attempt to index a node with a key that is not 0: " .. tostring(key))
		end
		-- we need to check if the hook is still valid, if priority changed OR if the hook was removed from the list, we check from events table
		local event = node.event
		local hook_table = event[node.name]
		if not hook_table then return EMPTY_FUNC end -- the hook was removed

		if hook_table.priority ~= node.priority then
			return EMPTY_FUNC
		end

		return hook_table.func -- return the new/up-to-date function
	end
}
local function CopyPriorityList(self, priority)
	local old_list = self[EVENTS_LISTS[priority]]
	local new_list = {}; do
		local j = 0
		for i = 1, old_list[0 --[[length]]] do
			local node = old_list[i]
			if not node.removed then -- don't copy removed hooks
				j = j + 1
				local new_node = {
					[0 --[[func]]] = node[0 --[[func]]],
					event = node.event,
					name = node.name,
					priority = node.priority,
					idx = j,
				}
				new_list[j] = new_node
				-- we need to update the node reference in the event table
				local hook_table = node.event[node.name]
				hook_table.node = new_node
			end
			-- we need to delete the function reference so __index can work properly
			-- we do it to all nodes because they can't be updated when hooks are added/removed, so they need to be able to check using __index
			node[0 --[[func]]] = nil
			setmetatable(node, node_meta)
		end
		new_list[0 --[[length]]] = j -- update the length
	end
	local list_index = EVENTS_LISTS[priority] -- 1 for normal hooks, 2 for post return hooks, 3 for post hooks
	self[list_index] = new_list
end

local function new_event(name)
	if not events[name] then
		local function GetPriorityList(self, priority)
			return self[EVENTS_LISTS[priority]]
		end

		-- [0] = list length
		local lists = {
			[1] = {[0] = 0}, -- normal hooks
			[2] = {[0] = 0}, -- post return hooks
			[3] = {[0] = 0}, -- post hooks

			CopyPriorityList = CopyPriorityList,
			GetPriorityList = GetPriorityList,
		}

		-- create the event table, we use [0] as hook names can't be numbers
		events[name] = {[0] = lists}
	end
	return events[name]
end

function GetTable()
	local new_table = {}
	for event_name, event in pairs(events) do
		local hooks = {}
		for i = 1, 3 do
			local list = event[0][i]
			for j = 1, list[0 --[[length]]] do
				local node = list[j]
				hooks[node.name] = event[node.name].real_func
			end
		end
		new_table[event_name] = hooks
	end
	return new_table
end

function Remove(event_name, name)
	if not isstring(event_name) then ErrorNoHaltWithStack("bad argument #1 to 'Remove' (string expected, got " .. type(event_name) .. ")") return end

	local notValid = isnumber(name) or isbool(name) or isfunction(name) or not name.IsValid
	if not isstring(name) and notValid then ErrorNoHaltWithStack("bad argument #2 to 'Remove' (string expected, got " .. type(name) .. ")") return end

	local event = events[event_name]
	if not event then return end -- no event with that name

	local hook_table = event[name]
	if not hook_table then return end -- no hook with that name

	hook_table.node.removed = true

	-- we need to overwrite the priority list with the new one, to make sure we don't mess up with ongoing iterations inside hook.Call/ProtectedCall
	-- we basically copy the list without the removed hook
	event[0 --[[lists]]]:CopyPriorityList(hook_table.priority)

	event[name] = nil -- remove the hook from the event table
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
		if priority == -2 or priority == 2 then -- ulx doesn't allow returning anything in monitor hooks
			local old_func = func
			func = function(...)
				old_func(...)
			end
		end
	elseif MAIN_PRIORITIES[priority] then
		if priority == PRE_HOOK then
			local old_func = func
			func = function(...) -- this is done to stop the function from returning anything
				old_func(...)
			end
		end
		priority = priority
	else
		if priority ~= nil then
			ErrorNoHaltWithStack("bad argument #4 to 'Add' (priority expected, got " .. type(priority) .. ")")
		end
		-- we probably don't want to stop the function here because it's not a critical error
		priority = NORMAL_HOOK
	end

	local event = new_event(event_name)

	-- check if the hook already exists
	do
		local hook_info = event[name]
		if hook_info then
			-- check if priority is different, if not then we just update the function
			if hook_info.priority == priority then
				hook_info.func = func
				hook_info.real_func = real_func
				hook_info.node[0 --[[func]]] = func -- update the function in the node
				return
			end
			-- if priority is different then we consider it a new hook
			Remove(event_name, name)
		else
			-- create a new hook list to use, we need to shadow the old one
			event[0]:CopyPriorityList(priority)
		end
	end

	local hook_list = event[0]:GetPriorityList(priority)

	local hk_n = hook_list[0 --[[length]]] + 1
	local node = {
		[0 --[[func]]] = func,
		event = event,
		name = name,
		priority = priority,
		idx = hk_n, -- this is used to keep order of the hooks based on when they were added, to have a consistent order
	}
	hook_list[hk_n] = node
	hook_list[0 --[[length]]] = hk_n

	event[name] = {
		name = name,
		priority = priority,
		func = func,
		real_func = real_func,
		node = node,
	}

	if NORMAL_PRIORITIES_ORDER[priority] then
		table.sort(hook_list, function(a, b)
			local a_order = NORMAL_PRIORITIES_ORDER[a.priority]
			local b_order = NORMAL_PRIORITIES_ORDER[b.priority]
			if a_order == b_order then
				return a.idx < b.idx
			end
			return a_order < b_order
		end)
	end
end

local gamemode_cache
function Run(name, ...)
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

	local lists = event[0 --[[lists]]]

	local hook_name, a, b, c, d, e, f

	do -- normal hooks
		local normal_hooks = lists[1]
		for i = 1, normal_hooks[0 --[[length]]] do
			local node = normal_hooks[i]
			local n_a, n_b, n_c, n_d, n_e, n_f = node[0 --[[func]]](...)
			if n_a ~= nil then
				hook_name, a, b, c, d, e, f = node.name, n_a, n_b, n_c, n_d, n_e, n_f
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

	-- we need to check if there is any post(return) hooks, if not then we can return early
	if lists[2][0 --[[length]]] == 0 and lists[3][0 --[[length]]] == 0 then
		return a, b, c, d, e, f
	end

	local returned_values = {hook_name, a, b, c, d, e, f}

	do -- post return hooks
		local post_return_hooks = lists[2]
		for i = 1, post_return_hooks[0 --[[length]]] do
			local node = post_return_hooks[i]
			local n_a, n_b, n_c, n_d, n_e, n_f = node[0 --[[func]]](returned_values, ...)
			if n_a ~= nil then
				a, b, c, d, e, f = n_a, n_b, n_c, n_d, n_e, n_f
				returned_values = {node.name, a, b, c, d, e, f}
				break
			end
		end
	end

	do -- post hooks
		local post_hooks = lists[3]
		for i = 1, post_hooks[0 --[[length]]] do
			local node = post_hooks[i]
			node[0 --[[func]]](returned_values, ...)
		end
	end

	return a, b, c, d, e, f
end

function ProtectedCall(event_name, gm, ...)
	local event = events[event_name]
	if not event then -- fast path
		if not gm then return end
		local gm_func = gm[event_name]
		if not gm_func then return end
		GProtectedCall(gm_func, gm, ...)
		return
	end

	local lists = event[0 --[[lists]]]

	do
		local normal_hooks = lists[1]
		for i = 1, normal_hooks[0 --[[length]]] do
			local node = normal_hooks[i]
			GProtectedCall(node[0 --[[func]]], ...)
		end
	end

	if gm then
		local gm_func = gm[event_name]
		if gm_func then
			GProtectedCall(gm_func, gm, ...)
		end
	end

	local returned_values = {nil, nil, nil, nil, nil, nil, nil}

	do
		local post_return_hooks = lists[2]
		for i = 1, post_return_hooks[0 --[[length]]] do
			local node = post_return_hooks[i]
			GProtectedCall(node[0 --[[func]]], returned_values, ...)
		end
	end

	do
		local post_hooks = lists[3]
		for i = 1, post_hooks[0 --[[length]]] do
			local node = post_hooks[i]
			GProtectedCall(node[0 --[[func]]], returned_values, ...)
		end
	end
end

function Debug(event_name)
	local event = events[event_name]
	if not event then
		print("No event with that name")
		return
	end

	local lists = event[0]
	print("------START------")
	print("event:", event_name)
	for i = 1, 3 do
		local list = lists[i]
		for j = 1, list[0 --[[length]]] do
			local node = list[j]
			print("----------")
			print("   name:", node.name)
			print("   func:", node[0])
			print("   real_func:", event[node.name].real_func)
			print("   priority:", PRIORITIES_NAMES[node.priority])
			print("   idx:", node.idx)
		end
	end
	print("-------END-------")
end

do -- ulx and dlib
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

		-- this could make an issue with addons that retrieve all hooks and call them, as POST_HOOK(_RETURN)
		-- will be called randomly and their first argument won't be the "returned values" table
		function GetULibTable()
			local new_events = {}

			for event_name, event in pairs(events) do
				local hooks = {[-2] = {}, [-1] = {}, [0] = {}, [1] = {}, [2] = {}}
				for i = 1, 3 do
					local list = event[0][i]
					for j = 1, list[0 --[[length]]] do
						local node = list[j]
						local priority = node.priority
						priority = isnumber(priority) and priority or priority[1]
						priority = math.Clamp(priority, -2, 2) -- just to make sure it's in the range
						local hook_table = event[node.name]
						hooks[priority][node.name] = hook_table.real_func
					end
				end
				new_events[event_name] = hooks
			end

			return new_events
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
