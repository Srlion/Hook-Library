# Hook-Library
This is a simple, realible, fast and optimized hook library for Garry's Mod.
It's well tested and will not mess anything when added to your server.
It can/should improve your server performance.

[Steam Workhop](https://steamcommunity.com/sharedfiles/filedetails/?id=1907060869)

## Benchmarks

```
CallInvalid (200 calls) (don't mind this one because it does not get called a lot in real-life usage)
Default:  0.001595900 s
Srlion: 0.009774000 s
Default is 512.44% faster
-------------
CallNoHooks (200000000 calls)
Default:  0.096520000 s
Srlion: 0.049093400 s
Srlion's is 96.60% faster
-------------
CallGMOnly (200000000 calls)
Default:  0.098468600 s
Srlion: 0.048702000 s
Srlion's is 102.19% faster
-------------
CallNoGM (32000000 calls)
Default:  5.810043300 s
Srlion: 0.015754100 s
Srlion's is 36779.56% faster
-------------
CallGM (32000000 calls)
Default:  6.230169500 s
Srlion: 0.008089000 s
Srlion's is 76920.27% faster
