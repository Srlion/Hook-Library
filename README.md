# Srlion's Hook Library
This is a ~~simple~~<sup>rip 2020~2021</sup> fat, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It **will** improve your server performance.

#### Thanks to [Meepen](https://www.gmodstore.com/users/76561198050165746) for his [hook library](https://github.com/meepen/gmod-hooks-revamped/blob/master/newhook.lua) because im using some ideas from it and inspired me to make this <3

------------

# Ulx support!
Now you can just drop it in your server and will replace ULib's hook library!
But you will have to watch for warnings that could appear if an addon tries to modify
```hook.GetULibTable``` directly to fix it.

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

# Benchmark
#### Using [this simple hook caller](https://github.com/Srlion/gmod-rs-simple-hook-test/tree/master) to do C++ -> Lua hook.Call

```lua
require("hooktest")

concommand.Add("hooktest", function()
	local insert = table.insert
	local tbl = {}
	for i = 1, 200 do
		hook.Add("HOOK_CALL_TEST", tostring(i), function(arg)
			insert(tbl, i)
		end)
	end

	print("Started hook bench test...")
	local time = HOOK_CALL_TEST()
	print("hook.Call: " .. time .. "s")
	print("~!")
end)
```

```
It's an average time for running the test 6 times

Srlion's hook.Call: 4.4750 seconds
	52.95% faster than default hook.Call
	130.84% faster than DLib's hook.Call

Default's hook.Call: 6.8447 seconds
	50.92% faster than DLib's hook.Call

DLib's hook.Call: 10.3301 seconds
```
### Around 52% faster!!!!!!
#### Hey, you're just boosting your server for free! No drawbacks, only extra goodies!
#### Imagine how many hooks get called every frame/second when you have 128 players in your server!

# Tested On [Physgun](https://billing.physgun.com/aff.php?aff=131) Dev Server
