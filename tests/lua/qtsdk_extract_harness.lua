-- Exercise libs/qtsdk.lua's extraction in a plain-Lua sandbox, against a FAKE
-- 7zz that plays the behaviours the recipe has to tell apart:
--
--   ok        exit 0, says nothing
--   chained   7-Zip 21+ refusing chained symlinks: exit 2, an ERROR line per
--             refused link, and a 0-byte regular file where each belongs
--   broken    the same message for a link whose siblings are not there, so
--             recreating it is impossible
--   other     exit 2 with a message that is not the link one and nothing to
--             repair
--
-- Prints one line per fact; tests/test_qtsdk_extract.py asserts on them.

local ROOT   = assert(os.getenv("FAKE_ROOT"), "FAKE_ROOT required")
local MODE   = assert(arg[1], "mode required")
local ARGLOG = ROOT .. "/7zz-args.txt"

-- ── the sandbox ────────────────────────────────────────────────────────
path = {}
function path.join(...)
    local parts = {...}
    local out = parts[1] or ""
    for i = 2, #parts do
        if out:sub(-1) == "/" then out = out .. parts[i]
        else out = out .. "/" .. parts[i] end
    end
    return out
end
function path.directory(p) return (p:gsub("/[^/]*$", "")) end
function path.filename(p) return (p:match("[^/]+$")) end

local function sh(cmd)
    local ok = os.execute(cmd)
    return ok == true or ok == 0
end
os.host = function() return "linux" end
os.isfile = function(p) return sh(string.format('test -f "%s"', p)) end
os.isdir = function(p) return sh(string.format('test -d "%s"', p)) end
os.tryrm = function(p) sh(string.format('rm -rf "%s"', p)); return true end
os.mkdir = function(p) return sh(string.format('mkdir -p "%s"', p)) end
os.cp = function(a, b) return sh(string.format('cp "%s" "%s"', a, b)) end
os.iorun = function(cmd)
    local f = io.popen(cmd .. " 2>/dev/null")
    local out = f:read("*a"); f:close(); return out
end
io.writefile = function(p, text)
    local f = assert(io.open(p, "w")); f:write(text); f:close(); return true
end
io.readfile = function(p)
    local f = io.open(p, "rb"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local logged = {}
local function logger(level)
    return function(...)
        local args = {...}
        local msg = #args > 1 and string.format(table.unpack(args)) or tostring(args[1])
        logged[#logged + 1] = level .. "\t" .. (msg:gsub("\n", "\\n"))
    end
end
local modules = {
    ["xim.libxpkg.log"]     = { info = logger("info"), warn = logger("warn"), error = logger("error"), debug = logger("debug") },
    ["xim.libxpkg.system"]  = { exec = function(cmd)
        if not sh(cmd) then error("exec failed: " .. cmd) end
    end },
    ["xim.libxpkg.fs"]      = { mkdir_p = function(p) return os.mkdir(p) end },
    ["xim.libxpkg.pkginfo"] = { build_dep = function(name)
        assert(name == "7zip", "asked for " .. tostring(name))
        return { path = ROOT .. "/sevenzip" }
    end },
}
-- import("xim.libxpkg.log") binds the global `log`, as the hook runtime does
function import(name)
    local m = modules[name]
    if not m then error("unexpected import: " .. name) end
    _G[name:match("[^.]+$")] = m
    return m
end

-- ── the fake 7zz ───────────────────────────────────────────────────────
sh(string.format('mkdir -p "%s/sevenzip"', ROOT))
local fake = ROOT .. "/sevenzip/7zz"
io.writefile(fake, [==[#!/bin/sh
echo "$*" >> "$FAKE_ROOT/7zz-args.txt"
out=""
for a in "$@"; do case "$a" in -o*) out="${a#-o}" ;; esac; done
case "$FAKE_7Z_MODE" in
ok)
    mkdir -p "$out/lib"; echo real > "$out/lib/libFoo.so.6.1"
    exit 0 ;;
chained)
    mkdir -p "$out/lib"
    for n in Foo Bar; do
        echo real > "$out/lib/lib$n.so.6.1"; ln -s lib$n.so.6.1 "$out/lib/lib$n.so.6"
        : > "$out/lib/lib$n.so"
        echo "ERROR: Dangerous link via another link was ignored : lib/lib$n.so : lib$n.so.6" >&2
    done
    exit 2 ;;
broken)
    mkdir -p "$out/lib"; : > "$out/lib/libLost.so"
    echo "ERROR: Dangerous link via another link was ignored : lib/libLost.so : libLost.so.6" >&2
    echo "ERROR: Data error : lib/libLost.so.6.1" >&2
    exit 2 ;;
other)
    mkdir -p "$out/lib"; echo real > "$out/lib/libFoo.so.6.1"
    echo "WARNING: something 7-Zip wants known" >&2
    exit 1 ;;
esac
exit 3
]==])
sh(string.format('chmod +x "%s"', fake))
-- The fake reads its mode from the environment; Lua has no setenv, so the
-- command carries it.
local plain_exec = modules["xim.libxpkg.system"].exec
modules["xim.libxpkg.system"].exec = function(cmd)
    plain_exec(string.format('FAKE_ROOT="%s" FAKE_7Z_MODE="%s" %s', ROOT, MODE, cmd))
end

-- ── the archive: present and correct, so nothing is fetched ────────────
local install_dir = ROOT .. "/install"
sh(string.format('rm -rf "%s" && mkdir -p "%s/.dl"', install_dir, install_dir))
local archive = install_dir .. "/.dl/fake.7z"
io.writefile(archive, "not a real archive\n")
local sha = os.iorun(string.format('sha256sum "%s"', archive)):match("^(%x+)")

local qtsdk = dofile(assert(os.getenv("QTSDK"), "QTSDK required"))
local ok = qtsdk.fetch_and_extract(
    { { module = "qtbase", name = "fake.7z", sha256 = sha, path = "unused" } },
    install_dir, install_dir .. "/marker.txt", "qt-test")

print("RETURN\t" .. tostring(ok))
for _, l in ipairs(logged) do print("LOG\t" .. l) end
local libdir = install_dir .. "/lib"
for _, n in ipairs({ "libFoo.so", "libBar.so", "libLost.so" }) do
    local p = libdir .. "/" .. n
    if sh(string.format('test -L "%s"', p)) then
        print("LINK\t" .. n .. "\t" .. os.iorun(string.format('readlink "%s"', p)):gsub("%s+$", ""))
    elseif os.isfile(p) then
        print("FILE\t" .. n .. "\t" .. #io.readfile(p))
    end
end
print("ARGS\t" .. (io.readfile(ARGLOG) or ""):gsub("\n$", ""))
print("LEFT\t" .. tostring(os.isfile(archive .. ".out")))
