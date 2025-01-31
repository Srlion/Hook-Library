# Srlion's Hook Library
This is a ~~simple~~<sup>rip 2020~2021</sup> fat, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It **will** improve your server performance.

#### Thanks to [Meepen](https://www.gmodstore.com/users/76561198050165746) for his [hook library](https://github.com/meepen/gmod-hooks-revamped/blob/master/newhook.lua) because im using some ideas from it and inspired me to make this <3

------------

# Ulx support!
Now you can just drop it in your server and will replace ULib's hook library!
But you will have to watch for warnings that could appear if an addon tries to modify
```hook.GetULibTable``` directly to fix it. Otherwise it's just drop in replacement.

# [Steam Workhop](https://steamcommunity.com/sharedfiles/filedetails/?id=1907060869)
##### Latest update is not on workshop yet, need to make sure that everything is working as intended to not kill lots of servers.

# Installation
Add this in: **addons/custom_hook/lua/includes/modules/hook.lua**

# Priorities
  * PRE_HOOK
  * PRE_HOOK_RETURN
  * NORMAL_HOOK **(Default)**
  * POST_HOOK_RETURN
  * POST_HOOK

# Usage
```lua
hook.Add(event_name, name, func, priority)
```

# Examples
### PRE_HOOK
#### This hook is guaranteed to be called under all circumstances, and cannot be interrupted by a return statement. You can rely on its consistent execution.
This primarily serves as a logging hook.
```lua
hook.Add("PlayerSay", "pre_player_say", function(sender, text)
	print(sender:Name() .. "is attempting to send a text: " .. text)
end, PRE_HOOK)
```

### PRE_HOOK_RETURN
Consider a scenario where you have an admin mod that checks for "!menu". In this case, your hook might not be called before it. To ensure that your hook runs prior to this and is able to check for your command, you can utilize PRE_HOOK_RETURN.
```lua
hook.Add("PlayerSay", "pre_return_player_say", function(sender, text)
	if text == "!superpower" then
		sender:give_superpower()
		return ""
	end
end, PRE_HOOK_RETURN)
```

### POST_HOOK_RETURN
This allows for the modification of results returned from preceding hooks!
```lua
-- arguments = {[1] = hook_name, [2] = returned_value_1, [3] = returned_value_2, ...etc}
-- hook_name can be the gamemode table that was passed to hook.Call
hook.Add("PlayerSay", "post_return_player_say", function(arguments, sender, text)
	local hook_name = arguments[1] -- This is the name of the hook that gave back a result.
	local returned_string = arguments[2]
	print(string.format("%s returned: %s, but we are changing it to : %s", hook_name, returned_string, "help"))
	return "help"
end, POST_HOOK_RETURN)
```

### POST_HOOK
#### This hook is guaranteed to be called under all circumstances, and cannot be interrupted by a return statement. You can rely on its consistent execution.
##### Modifications made by POST_HOOK_RETURN will also modify the results in POST_HOOK
This primarily serves as a logging hook.
```lua
-- arguments = {[1] = hook_name, [2] = returned_value_1, [3] = returned_value_2, ...etc}
-- hook_name can be the gamemode table that was passed to hook.Call
hook.Add("PlayerSay", "post_player_say", function(arguments, sender, text)
	local hook_name = arguments[1] -- This is the name of the hook that gave back a result.
	local returned_string = arguments[2]
	print(string.format("%s said: %s", sender, text))
end, POST_HOOK)
```

# Benchmarks
#### Using [this simple hook caller](https://github.com/Srlion/gmod-rs-simple-hook-test/tree/master) to do C++ -> Lua hook.Call

## Empty 500 Calls - jit.off() in lua/includes/init.lua
```lua
concommand.Add("hooktest", function()
	require("hooktest")

	for i = 1, 500 do
		hook.Add("HOOK_CALL_TEST", tostring(i), function(arg)
		end)
	end

	print("Number of hooks: " .. table.Count(hook.GetTable().HOOK_CALL_TEST))

	print("Warming up...")
	HOOK_CALL_TEST()

	local calls_sum = 0

	print("Starting hook bench test...")
	for i = 1, 6 do
		calls_sum = calls_sum + HOOK_CALL_TEST()
	end

	print("hook.Call average time: " .. math.Round(calls_sum / 6, 3) .. " seconds")
	print("~!")
end)
```

```
Srlion's hook.Call: 1.775 seconds
	Faster than ULX's hook by 56.90%
	Faster than Default's hook by 325.58%
	Faster than DLib's hook by 597.46%

ULX's hook.Call: 2.785 seconds
	Faster than Default's hook by 171.24%
	Faster than DLib's hook by 344.52%

Default's hook.Call: 7.554 seconds
	Faster than DLib's hook by 63.89%

DLib's hook.Call: 12.380 seconds
```

## CurTime() 250 Calls
```lua
concommand.Add("hooktest", function()
	require("hooktest")

	local CurTime = CurTime
	for i = 1, 250 do
		hook.Add("HOOK_CALL_TEST", tostring(i), function(arg)
			CurTime()
		end)
	end

	print("Number of hooks: " .. table.Count(hook.GetTable().HOOK_CALL_TEST))

	print("Warming up...")
	HOOK_CALL_TEST()

	local calls_sum = 0

	print("Starting hook bench test...")
	for i = 1, 6 do
		calls_sum = calls_sum + HOOK_CALL_TEST()
	end

	print("hook.Call average time: " .. math.Round(calls_sum / 6, 3) .. " seconds")
	print("~!")
end)
```
```
Srlion's hook.Call: 1.775 seconds
	Faster than ULX's hook by 21.86%
	Faster than Default's hook by 216.96%
	Faster than DLib's hook by 326.70%

ULX's hook.Call: 2.163 seconds
	Faster than Default's hook by 160.10%
	Faster than DLib's hook by 250.16%

Default's hook.Call: 5.626 seconds
	Faster than DLib's hook by 34.62%

DLib's hook.Call: 7.574 seconds
```
#### Hey, you're just boosting your server for free! No drawbacks, only extra goodies!

# Tested On [Physgun](https://billing.physgun.com/aff.php?aff=131) Dev Server
**Gamemode:** Sandbox

- Lua Refresh -> **OFF**
- Physgun Utils -> **OFF**
