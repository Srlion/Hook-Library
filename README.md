# Hook-Library
This is a simple, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It can/should improve your server performance.

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
Srlion's Lib took 0.113439200 s

Default Lib...
Default Lib took 2.034281600 s

-------------
CallNoHooks (20000000 calls)
Srlion's Lib (1.16% faster)
Default Lib:  0.020502000 s
Srlion's Lib: 0.020266400 s
-------------
CallGMOnly (20000000 calls)
Srlion's Lib (3.04% faster)
Default Lib:  0.031323000 s
Srlion's Lib: 0.030400000 s
-------------
CallNoGM (3200000 calls)
Srlion's Lib (30488.68% faster)
Default Lib:  1.021784100 s
Srlion's Lib: 0.003340400 s
-------------
CallGM (3200000 calls)
Srlion's Lib (28420.08% faster)
Default Lib:  0.956363700 s
Srlion's Lib: 0.003353300 s
-------------
```
### Jit Off
```
Srlion's Lib...
Srlion's Lib took 3.215370000 s

Default Lib...
Default Lib took 4.222064900 s

-------------
CallNoHooks (20000000 calls)
Default Lib (4.91% faster)
Default Lib:  0.429621100 s
Srlion's Lib: 0.450715900 s
-------------
CallGMOnly (20000000 calls)
Srlion's Lib (0.54% faster)
Default Lib:  0.695163200 s
Srlion's Lib: 0.691419400 s
-------------
CallNoGM (3200000 calls)
Srlion's Lib (61.58% faster)
Default Lib:  1.538600300 s
Srlion's Lib: 0.952240700 s
-------------
CallGM (3200000 calls)
Srlion's Lib (56.35% faster)
Default Lib:  1.554477600 s
Srlion's Lib: 0.994227400 s
-------------
```
