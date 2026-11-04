#!/bin/bash
# Type-check with Roblox API definitions; show only errors that matter (API misuse, syntax, globals, requires)
cd ~/beach
~/tools/rojo sourcemap default.project.json -o sourcemap.json >/dev/null
~/tools/luau-lsp analyze --definitions=$HOME/tools/lsprepo/scripts/globalTypes.None.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src 2>&1 \
  | grep -v "^\[" | sed 's#/root/beach/##' \
  | grep -E "external type|SyntaxError|Unknown global|Unknown require|Argument count|not callable|Unknown type|is not a valid member|deprecated|LocalShadow|UnknownGlobal|FunctionUnused|Cannot call|could not be converted into 'Instance'|Enum|Unreachable|Key '[A-Za-z_]+' not found in external" \
  | grep -v "Config/Treasures.lua\|Config/Achievements.lua"
