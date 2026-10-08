#!/usr/bin/env python3
"""Tiny Rojo-like bridge to Roblox Studio through the Studio MCP proxy.

Usage:
  tools/studio.py sync            push src/ into the open Studio place
  tools/studio.py run FILE.luau [FILE2.luau ...]
                                  execute Luau file(s) in the Edit datamodel
                                  (multiple files are concatenated into one chunk)
  tools/studio.py build           rebuild the whole map (tools/build/*, in order)

File mapping (under src/):
  <Service>/<Folder>/.../Name.luau         -> ModuleScript
  <Service>/<Folder>/.../Name.server.luau  -> Script
  <Service>/<Folder>/.../Name.client.luau  -> LocalScript
  directories                              -> Folder (created if missing)
  a directory containing init.luau / init.server.luau / init.client.luau
  becomes that script, with the other files as its children.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_ORDER = ["lib.luau", "world.luau", "mine1.luau", "mine2.luau", "mine3.luau", "mine4.luau", "mine5.luau", "mine6.luau", "camp.luau"]
SRC = ROOT / "src"
VINEGAR = Path.home() / ".local/share/vinegar"
WINE = VINEGAR / "kombucha/bin/wine"


def find_mcp_exe() -> Path:
    exes = sorted((VINEGAR / "versions").glob("*/StudioMCP.exe"), key=lambda p: p.stat().st_mtime)
    if not exes:
        sys.exit("StudioMCP.exe not found under vinegar versions")
    return exes[-1]


class Mcp:
    def __init__(self):
        env = dict(os.environ, WINEPREFIX=str(VINEGAR / "prefixes/studio"), WINELOADERNOEXEC="1")
        self.p = subprocess.Popen([str(WINE), str(find_mcp_exe())], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env, text=True)
        self.next_id = 1
        self.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                    "clientInfo": {"name": "studio.py", "version": "1"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, msg):
        self.p.stdin.write(json.dumps(msg) + "\n")
        self.p.stdin.flush()

    def request(self, method, params):
        rid = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
        while True:
            line = self.p.stdout.readline()
            if not line:
                sys.exit("MCP proxy closed unexpectedly")
            msg = json.loads(line)
            if msg.get("id") == rid:
                if "error" in msg:
                    sys.exit(f"MCP error: {msg['error']}")
                return msg["result"]

    def call(self, name, args):
        res = self.request("tools/call", {"name": name, "arguments": args})
        text = "".join(c.get("text", "") for c in res.get("content", []))
        if res.get("isError"):
            sys.exit(f"{name} failed: {text}")
        return text

    def studio_id(self):
        for _ in range(10):
            studios = json.loads(self.call("list_roblox_studios", {}))["studios"]
            if studios:
                return studios[0]["id"]
            time.sleep(1)
        sys.exit("No Roblox Studio instance connected")

    def close(self):
        self.p.terminate()


def long_string(s: str) -> str:
    level = 0
    while f"]{'=' * level}]" in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{s}]{eq}]"


def classify(name: str):
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if name.endswith(suffix):
            return name[: -len(suffix)], cls
    return None, None


def collect():
    """Yield (path_parts, className, source) in parent-before-child order."""
    items = []

    def walk(directory: Path, parts):
        init = None
        for cand in ("init.server.luau", "init.client.luau", "init.luau"):
            if (directory / cand).exists():
                init = cand
        if parts and len(parts) > 1:
            if init:
                _, cls = classify(init)
                items.append((parts, cls, (directory / init).read_text()))
            else:
                items.append((parts, "Folder", None))
        for child in sorted(directory.iterdir()):
            if child.is_dir():
                walk(child, parts + [child.name])
            elif child.name != init:
                name, cls = classify(child.name)
                if cls:
                    items.append((parts + [name], cls, child.read_text()))

    walk(SRC, [])
    return items


SYNC_PRELUDE = """
local function ensure(parts, className)
    local node = game:GetService(parts[1])
    for i = 2, #parts do
        local child = node:FindFirstChild(parts[i])
        local last = i == #parts
        if child and last and className ~= "Folder" and child.ClassName ~= className then
            child:Destroy()
            child = nil
        end
        if not child then
            child = Instance.new(last and className or "Folder")
            child.Name = parts[i]
            child.Parent = node
        end
        node = child
    end
    return node
end
local count = 0
local function put(parts, className, source)
    local inst = ensure(parts, className)
    if source then inst.Source = source end
    count += 1
end
"""


def sync(mcp, sid):
    items = collect()
    chunks, cur, size = [], [], 0
    for parts, cls, source in items:
        stmt = f"put({json.dumps(parts).replace('[', '{').replace(']', '}')}, {json.dumps(cls)}, " \
               f"{long_string(source) if source is not None else 'nil'})\n"
        if size + len(stmt) > 60000 and cur:
            chunks.append(cur)
            cur, size = [], 0
        cur.append(stmt)
        size += len(stmt)
    if cur:
        chunks.append(cur)
    for chunk in chunks:
        code = SYNC_PRELUDE + "".join(chunk) + "return 'synced ' .. count"
        print(mcp.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": code}))
    print(f"{len(items)} instances in src/")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    mcp = Mcp()
    try:
        sid = mcp.studio_id()
        if sys.argv[1] == "sync":
            sync(mcp, sid)
        elif sys.argv[1] in ("run", "build"):
            files = sys.argv[2:] if sys.argv[1] == "run" else [ROOT / "tools/build" / f for f in BUILD_ORDER]
            code = "\n".join(Path(f).read_text() for f in files)
            print(mcp.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": code}))
        else:
            sys.exit(__doc__)
    finally:
        mcp.close()


if __name__ == "__main__":
    main()
