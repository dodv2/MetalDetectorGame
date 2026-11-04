# Beach Detecting Simulator

A coastal treasure-hunting Roblox simulator: sweep beaches with a metal detector, dig treasures out in a
tug of war with the sand, then sell them or display them in your own shop to afford better gear and new beaches.

## Build

Rojo 7.4 project (Luau).

```
rojo build default.project.json -o BeachDetectingSimulator.rbxlx
```

Open the `.rbxlx` in Roblox Studio. The map lives in `map/Map.rbxmx` (`tools/gen_map_u16_legacy.py` is the old
Update 16 generator - don't use it to regenerate the map).

- `src/server` - ServerScriptService (Main + Services)
- `src/client` - StarterPlayerScripts (ClientMain + Controllers + UI)
- `src/shared` - ReplicatedStorage.Shared (Config, models, maths)
- `tests` - Lune tests: `lune run tests/config_test.luau`, `lune run tests/shop_test.luau`
- `tools/check.sh` - luau-lsp type check
