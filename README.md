# PRIORITIES ADDED! PLEASE TEST
Need to make sure it's working without issues before releasing it on workshop and add support for ulx, please test!

# Hook-Library
This is a simple, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It can/should improve your server performance.
NOW WITH PRIORITIES!!!

# Usage
```lua
hook.Add(event_name, name, func, priority)
```


# Priorities
  * hook.MONITOR_HIGH
  * hook.HIGH
  * hook.NORMAL
  * hook.LOW
  * hook.MONITOR_LOW

# Installation
Add this in: addons/custom_hook/lua/includes/modules/hook.lua

[Steam Workhop](https://steamcommunity.com/sharedfiles/filedetails/?id=1907060869)

Thanks to [Meepen](https://www.gmodstore.com/users/76561198050165746) for his [hook library](https://github.com/meepen/gmod-hooks-revamped/blob/master/newhook.lua) because im using some ideas from it and inspired me to make this :D

# Benchmarks

### Jit On
```
Srlion's Lib...
Srlion's Lib took 0.067895000 s

Default Lib...
Default Lib took 1.589598100 s

-------------
CallGMOnly (20000000 calls)
Default Lib (1.87% faster)
Default Lib:  0.039815600 s
Srlion's Lib: 0.040561900 s
-------------
CallNoGM (3200000 calls)
Srlion's Lib (19409.60% faster)
Default Lib:  0.741989100 s
Srlion's Lib: 0.003803200 s
-------------
CallNoHooks (20000000 calls)
Default Lib (0.23% faster)
Default Lib:  0.019999400 s
Srlion's Lib: 0.020045400 s
-------------
CallGM (3200000 calls)
Srlion's Lib (23540.47% faster)
Default Lib:  0.787747700 s
Srlion's Lib: 0.003332200 s
-------------
```
### Jit Off
```
Srlion's Lib...
Srlion's Lib took 2.151561600 s

Default Lib...
Default Lib took 2.774747700 s

-------------
CallGMOnly (20000000 calls)
Default Lib (0.01% faster)
Default Lib:  0.677981500 s
Srlion's Lib: 0.678061100 s
-------------
CallNoGM (3200000 calls)
Srlion's Lib (60.90% faster)
Default Lib:  0.833078200 s
Srlion's Lib: 0.517748400 s
-------------
CallNoHooks (20000000 calls)
Srlion's Lib (0.69% faster)
Default Lib:  0.406495000 s
Srlion's Lib: 0.403708900 s
-------------
CallGM (3200000 calls)
Srlion's Lib (55.29% faster)
Default Lib:  0.857146200 s
Srlion's Lib: 0.551969900 s
-------------
```
