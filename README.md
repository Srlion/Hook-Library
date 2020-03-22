# Hook-Library
This is a simple, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It can/should improve your server performance.

[Steam Workhop](https://steamcommunity.com/sharedfiles/filedetails/?id=1907060869)

Thanks to [Meepen](https://www.gmodstore.com/users/76561198050165746) for his [hook library](https://github.com/meepen/gmod-hooks-revamped/blob/master/newhook.lua) because im using some ideas from it and inspired me to make this :D

## Benchmarks

```
Srlion's New Lib...
Srlion's New Lib took 0.511766100 s

Default Lib...
Default Lib took 14.408792900 s

BENCHMARK
CallInvalid (500 calls)
Srlion's New Lib (218.29% faster)
Default Lib:      0.005260700 s
Srlion's New Lib: 0.001652800 s
-------------
CallNoHooks (200000000 calls)
Default Lib (1.36% faster)
Default Lib:      0.213272500 s
Srlion's New Lib: 0.216162900 s
-------------
CallGMOnly (200000000 calls)
Default Lib (2.97% faster)
Default Lib:      0.215109900 s
Srlion's New Lib: 0.221490100 s
-------------
CallNoGM (32000000 calls)
Srlion's New Lib (19258.95% faster)
Default Lib:      6.825907900 s
Srlion's New Lib: 0.035259700 s
-------------
CallGM (32000000 calls)
Srlion's New Lib (19239.46% faster)
Default Lib:      7.149178400 s
Srlion's New Lib: 0.036966800 s
