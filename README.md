# Salty

Salty is a Roblox runtime remote/network inspection tool maintained by **MrRos3**.

## Execute

Use the loader so Salty includes the compatibility hooks:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrRos3/Salty/main/loader.lua"))()
```

## Project files

- `Salty.luau` — complete bundled Salty runtime.
- `compat.lua` — fallback Incoming/Outgoing hook layer for executors where the bundled hook path stays silent.
- `loader.lua` — stable entry point that loads both the bundled runtime and compatibility layer.
- `VERSION` — current Salty repository version marker.

Lucide icon data used by Salty is hosted in the maintainer's `MrRos3/Icons` repository.
