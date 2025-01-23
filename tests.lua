-- lots of testing cases are taken from meepen https://github.com/meepen/gmod-hooks-revamped/blob/master/hooksuite.lua
-- big thanks to him really for his great work
-- (when i was making the library i was testing lots of random cases and i never noted them down, there were lots of shady cases but unfortunately they are gone)
-- Add it to the bottom of hook.lua file and then run hook.Test() in console to run the tests

local assert = _GLOBAL.assert
local insert = table.insert
local pcall = _GLOBAL.pcall
local Call, Run, Add, Remove = Call, Run, Add, Remove

local TEST = {}

-- this is to check if hooks order is by first to last or last to first

setmetatable(TEST, {
	__call = function(self, func)
		insert(self, func)
	end
})

-- Basic add and call test
TEST(function(name)
	local gm_table = {}
	gm_table[name] = function(gm, ret)
		return ret
	end

	local ran = false
	Add(name, "1", function()
		ran = true
	end)

	local ret = Call(name, gm_table, 1)

	assert(ran == true, "hook.Call didn't run the hook")
	assert(ret == 1, "hook.Call didn't run the gamemode function or returned the wrong value")
end)

-- Adding hooks with same priority
TEST(function(name)
	local order = {}
	for i = 1, 3 do
		Add(name, tostring(i), function() table.insert(order, tostring(i)) end, NORMAL_PRIORITY)
	end

	Call(name, {})

	assert(table.concat(order) == "123", "Hooks with the same priority did not execute in order of addition")
end)

-- Remove hook test
TEST(function(name)
	local executed = {}
	Add(name, "hook1", function() table.insert(executed, "hook1") end)
	Add(name, "hook2", function() table.insert(executed, "hook2") end)

	Remove(name, "hook1")
	Call(name, {})

	assert(not table.HasValue(executed, "hook1"), "Removed hook should not execute")
end)

-- Replace hook functionality
TEST(function(name)
	local executed = false
	Add(name, "hook", function() executed = true end)
	Add(name, "hook", function() executed = false end)

	Call(name, {})

	assert(executed == false, "Hook should have its functionality replaced")
end)

-- Chain of hooks
TEST(function(name)
	local order = {}
	for i = 1, 5 do
		Add(name, "hook" .. tostring(i), function() table.insert(order, "hook" .. tostring(i)) end)
	end

	Call(name, {})

	assert(table.concat(order) == "hook1hook2hook3hook4hook5", "Complex chain of hooks did not execute correctly")
end)

-- Concurrent add/remove during call
TEST(function(name)
	local dynamic_hook = function() Remove(name, "dynamic") end
	Add(name, "static", function() Add(name, "dynamic", dynamic_hook) end)

	Call(name, {})

	assert( pcall(Call, name, {}), "Should be stable after concurrent add/remove during call")
end)

-- Nested hok calls
TEST(function(name)
	local nested_called = false
	Add(name, "outer", function() Call("nested", {}) end)
	Add("nested", "inner", function() nested_called = true end)

	Call(name, {})

	assert(nested_called, "Nested hook calls should be handled correctly")
end)

-- Hooks with variable arguments
TEST(function(name)
	local args_received = false
	Add(name, "varargs", function(...) args_received = {...} end)

	Call(name, {}, 1, 2, 3)

	assert(#args_received == 3 and args_received[1] == 1 and args_received[2] == 2 and args_received[3] == 3, "Hooks should handle variable arguments correctly")
end)

-- Hook call with gamemode function and no hooks
TEST(function(name)
	local gm_table = {}
	gm_table[name] = function() return "gm_called" end

	local ret = Call(name, gm_table)

	assert(ret == "gm_called", "The gamemode function should run and return its value when no hooks are present")
end)


-- PreHook with return stopping execution
TEST(function(name)
	local gm_table = {}
	gm_table[name] = function() return "gm_not_called" end
	local returnValue = nil
	Add(name, "PreHookReturn", function() return "pre_returned" end, PRE_HOOK_RETURN)

	returnValue = Call(name, gm_table)

	assert(returnValue == "pre_returned", "Pre-hook with return should stop execution and return its value")
end)

-- Normal hook running with PostHook present
TEST(function(name)
	local normal_hook_ran = false
	local post_hood_ran = false
	Add(name, "normalhook", function() normal_hook_ran = true end, NORMAL_HOOK)
	Add(name, "posthook", function() post_hood_ran = true end, POST_HOOK)

	Call(name, {})

	assert(normal_hook_ran and post_hood_ran, "Both normal and posthooks should run")
end)

-- Post-Hook with return modifying overall return value
TEST(function(name)
	local return_value = nil
	Add(name, "normalhook", function() return "original_return" end, NORMAL_HOOK)
	Add(name, "posthookreturn", function() return "post_modified" end, POST_HOOK_RETURN)

	return_value = Call(name, {})

	assert(return_value == "post_modified", "Post-hook with return should modify the overall return value")
end)

-- Post-Hook without return not modifying overall return value
TEST(function(name)
	local return_value = nil
	Add(name, "normalhook", function() return "original_return" end, NORMAL_HOOK)
	Add(name, "posthook", function() end, POST_HOOK)

	return_value = Call(name, {})

	assert(return_value == "original_return", "Post-hook without return should not modify the overall return value")
end)

-- Post-Hok running after gamemode function
TEST(function(name)
	local gm_table = {}
	gm_table[name] = function() return "gm_called" end
	local posthook_ran = false
	Add(name, "postHook", function() posthook_ran = true end, POST_HOOK)

	local return_value = Call(name, gm_table)

	assert(posthook_ran and return_value == "gm_called", "Post-hook should run after gamemode function")
end)

-- Post-Hook modifying gamemode function return value
TEST(function(name)
	local gm_table = {}
	gm_table[name] = function() return "gm_called" end
	Add(name, "postHookreturn", function() return "post_modified" end, POST_HOOK_RETURN)

	local return_value = Call(name, gm_table)

	assert(return_value == "post_modified", "Post-hook should modify the return value of the gamemode function")
end)

-- Hook remove during execution
TEST(function(name)
	local hookran = false
	local removing_hook = function() Remove(name, "dynamicHook") end
	Add(name, "removing_hook", removing_hook, PRE_HOOK)
	Add(name, "dynamicHook", function() hookran = true end, NORMAL_HOOK)

	Call(name, {})

	assert(not hookran, "Hook should not run after being removed")
end)

-- Test weird adding in calls
TEST(function(name)
	local a, b, b2, c
	Add(name, "a", function()
		a = true
		Remove(name, "a")
		Add(name, "b", function()
			b2 = true
		end)
	end)

	Add(name, "c", function()
		c = true
	end)

	Add(name, "b", function()
		b = true
	end)

	Call(name)
	assert(a == true and b == nil and b2 == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " b2: " .. tostring(b2) .. " c: " .. tostring(c))
	a, b, b2, c = nil, nil, nil, nil
	Call(name)
	assert(a == nil and b == nil and b2 == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " b2: " .. tostring(b2) .. " c: " .. tostring(c))
end)

-- Test adding a hook inside hook.Call to make sure that the new added hook wont be called in the current hook.Call
-- gmod default behavior is wrong here, read https://github.com/Facepunch/garrysmod/pull/1642#issuecomment-601288451
TEST(function(name)
	local a, b, c
	Add(name, "a", function()
		a = true
		Add(name, "c", function()
			c = true
		end)
	end)
	Add(name, "b", function()
		b = true
	end)

	Call(name)
	assert(a == true and b == true and c == nil, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " c: " .. tostring(c))
	a, b, c = nil, nil, nil
	Call(name)
	assert(a == true and b == true and c == true, "something is wrong, called: a: " .. tostring(a) .. " b: " .. tostring(b) .. " c: " .. tostring(c))
end)

-- Test calling with no return values in normal hook, gm should run
TEST(function(name)
	local gm_called, normal_called, post_called

	local gm_table = {
		[name] = function(gm)
			gm_called = true
		end,
	}

	Add(name, "NORMAL_HOOK", function()
		normal_called = true
	end)

	Add(name, "POST_HOOK_RETURN", function(returned_value)
		assert(returned_value[1] == gm_table, "something is wrong")
		post_called = true
	end, POST_HOOK_RETURN)

	assert(Call(name, gm_table) == nil and normal_called == true and post_called == true and gm_called == true, "something is wrong: normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
end)

-- Test calling with return values in normal hook, gm should not run
TEST(function(name)
	local gm_called, normal_called, post_called

	local gm_table = {
		[name] = function(gm)
			gm_called = true
		end
	}

	Add(name, "NORMAL_HOOK", function()
		normal_called = true
		return "NORMAL_HOOK"
	end)

	Add(name, "POST_HOOK_RETURN", function(returned_value)
		assert(returned_value[1] == "NORMAL_HOOK", "something is wrong")
		post_called = true
	end, POST_HOOK_RETURN)

	local returned = Call(name, gm_table)
	assert(returned == "NORMAL_HOOK" and normal_called == true and post_called == true and gm_called == nil, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
end)

-- Test calling with no return values in normal hook, and gm returns values
TEST(function(name)
	local gm_called, normal_called, post_called

	local gm_table = {
		[name] = function(gm)
			gm_called = true
			return "GM_RETURN"
		end
	}

	Add(name, "NORMAL_HOOK", function()
		normal_called = true
	end)

	Add(name, "POST_HOOK_RETURN", function(returned_value)
		assert(returned_value[1] == gm_table and returned_value[2] == "GM_RETURN", "something is wrong")
		post_called = true
	end, POST_HOOK_RETURN)

	local returned = Call(name, gm_table)
	assert(returned == "GM_RETURN" and normal_called == true and post_called == true and gm_called == true, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
end)

-- Test calling with post hook modifies normal hook return, gm shouldnt run
TEST(function(name)
	local gm_called, normal_called, post_called

	local gm_table = {
		[name] = function(gm)
			gm_called = true
		end
	}

	Add(name, "NORMAL_HOOK", function()
		normal_called = true
		return "NORMAL_HOOK"
	end)

	Add(name, "POST_HOOK_RETURN", function(returned_value)
		assert(returned_value[1] == "NORMAL_HOOK", "something is wrong")
		post_called = true
		return "POST_HOOK_RETURN"
	end, POST_HOOK_RETURN)

	local returned = Call(name, gm_table)
	assert(returned == "POST_HOOK_RETURN" and normal_called == true and post_called == true and gm_called == nil, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
end)

-- Test calling with post hook modifies gm function return
TEST(function(name)
	local gm_called, normal_called, post_called

	local gm_table = {
		[name] = function(gm)
			gm_called = true
			return "GM_RETURN"
		end
	}

	Add(name, "NORMAL_HOOK", function()
		normal_called = true
	end)

	Add(name, "POST_HOOK_RETURN", function(returned_value)
		assert(returned_value[1] == gm_table and returned_value[2] == "GM_RETURN", "something is wrong")
		post_called = true
		return "POST_HOOK_RETURN"
	end, POST_HOOK_RETURN)

	local returned = Call(name, gm_table)
	assert(returned == "POST_HOOK_RETURN" and normal_called == true and post_called == true and gm_called == true, "something is wrong: returned: " .. tostring(returned) .. " normal_called: " .. tostring(normal_called) .. " post_called: " .. tostring(post_called) .. " gm_called: " .. tostring(gm_called))
end)

TEST(function(name)
	local call_orders = {}
	Add(name, "PRE_HOOK", function(arg1, arg2, arg3)
		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "PRE_HOOK didn't get the right argument")
		insert(call_orders, PRE_HOOK)
	end, PRE_HOOK)

	Add(name, "PRE_HOOK_RETURN", function(arg1, arg2, arg3)
		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "PRE_HOOK_RETURN didn't get the right argument")
		insert(call_orders, PRE_HOOK_RETURN)
	end, PRE_HOOK_RETURN)

	Add(name, "NORMAL_HOOK", function(arg1, arg2, arg3)
		assert(arg1 == 1 and arg2 == 2 and arg3 == 3, "NORMAL_HOOK didn't get the right argument")
		insert(call_orders, NORMAL_HOOK)
		return "testing_returns"
	end, NORMAL_HOOK)

	Add(name, "POST_HOOK_RETURN", function(returned_values, arg1, arg2, arg3)
		assert(returned_values[1] == "NORMAL_HOOK" and returned_values[2] == "testing_returns" and arg1 == 1 and arg2 == 2 and arg3 == 3, "POST_HOOK_RETURN didn't get the right argument")
		insert(call_orders, POST_HOOK_RETURN)
		return "testing_post_return"
	end, POST_HOOK_RETURN)

	Add(name, "POST_HOOK", function(returned_values, arg1, arg2, arg3)
		assert(returned_values[1] == "POST_HOOK_RETURN" and returned_values[2] == "testing_post_return" and arg1 == 1 and arg2 == 2 and arg3 == 3, "POST_HOOK didn't get the right argument")
		insert(call_orders, POST_HOOK)
	end, POST_HOOK)

	Call(name, nil, 1, 2, 3)

	local expected_call_orders = {
		PRE_HOOK,
		PRE_HOOK_RETURN,
		NORMAL_HOOK,
		POST_HOOK_RETURN,
		POST_HOOK,
	}

	for i = 1, #expected_call_orders do
		if call_orders[i] ~= expected_call_orders[i] then
			error("something is wrong, expected: " .. expected_call_orders[i][1] .. " got: " .. call_orders[i][1])
		end
	end
end)

TEST(function(name)
	local entity = {
		IsValid = function()
			return true
		end
	}

	Add(name, entity, function()
		return true
	end)

	assert(Call(name, nil, 1) == true, "hook.Call didn't run the hook or returned the wrong value")
end)

TEST(function(name)
	local called = 1
	local entity = {
		IsValid = function()
			called = called + 1
			if called <= 2 then
				return true
			end
			return false
		end
	}

	Add(name, entity, function()
		return true
	end)

	assert(Call(name, nil, 1) == true, "hook.Call didn't run the hook or returned the wrong value")
	assert(Call(name, nil, 1) == nil, "hook.Call entity was called even though it became invalid")
end)

TEST(function(name)
	local entity = {
		IsValid = function()
			return true
		end
	}

	local entity_call_count = 0
	Add(name, entity, function()
		entity_call_count = entity_call_count + 1
	end)

	local call_count = 0
	Add(name, "1", function()
		call_count = call_count + 1
		return 1
	end)

	assert(Call(name, nil, 1) == 1, "hook.Call didn't run the hook or returned the wrong value")
	assert(call_count == 1, "call count is wrong: " .. call_count)
	assert(entity_call_count == 1, "entity call count is wrong: " .. entity_call_count)

	call_count = 0
	assert(Call(name, nil, 1) == 1, "hook.Call didn't run the hook or returned the wrong value")
	assert(call_count == 1, "call count is wrong: " .. call_count)
end)

TEST(function(name)
	Add(name, "1", function()
		Remove(name, "1")
	end)

	Add(name, "2", function()
		return 1
	end, POST_HOOK_RETURN)

	Call(name, nil, 1)
end)

TEST(function(name)
	local called = false

	Add(name, "1", function()
		return 1
	end, PRE_HOOK)

	Add(name, "2", function()
		called = true
		return 2
	end, PRE_HOOK)

	Call(name)
	assert(called == true, "hook.Call didn't run the hook or returned the wrong value")
end)

local test_name = "srlion_hook_test"
function Test()
	print("Starting hook test...")
	for i = 1, #TEST do
		TEST[i](test_name .. tostring({}) .. tostring(i))
	end
	print("Hook test is done!")
end
