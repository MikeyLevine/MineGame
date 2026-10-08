#!/usr/bin/env bash
# Launches the Roblox Studio MCP server (StudioMCP.exe) under Vinegar's Wine.
# Studio updates change the version-<hash> folder, so pick the newest one
# that contains StudioMCP.exe instead of hard-coding the path.
set -euo pipefail
VINEGAR="$HOME/.local/share/vinegar"
exe=$(ls -td "$VINEGAR"/versions/version-*/StudioMCP.exe 2>/dev/null | head -n1)
if [[ -z "$exe" ]]; then
  echo "studio-mcp: no StudioMCP.exe found under $VINEGAR/versions" >&2
  exit 1
fi
export WINEPREFIX="$VINEGAR/prefixes/studio"
export WINE_D3D_CONFIG="renderer=vulkan"
export WINELOADERNOEXEC=1
exec "$VINEGAR/kombucha/bin/wine" "$exe" "$@"
