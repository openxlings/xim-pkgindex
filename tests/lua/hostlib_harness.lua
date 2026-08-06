-- Exercise libs/hostlib.lua in a plain-Lua sandbox, the way libxpkg runs a
-- hook: no xmake, only the handful of globals the prelude provides.
--
-- The interesting case is the BIARCH host (Fedora/RHEL/SUSE): a 32-bit copy of
-- the soname in /usr/lib and the real 64-bit one in /usr/lib64. That is the
-- shape mcpp#352 got wrong, and it cannot be caught by ordering alone.

local ROOT = assert(os.getenv("FAKE_ROOT"), "FAKE_ROOT required")

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

local _isfile = function(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end
os.isfile = _isfile
os.isdir = function(p)
    -- `ls -d` on a directory succeeds and on a file also succeeds, so test the
    -- trailing-slash form: only a directory answers that.
    local ok = os.execute(string.format('test -d "%s"', p))
    return ok == true or ok == 0
end
os.iorun = function(cmd)
    local f = io.popen(cmd)
    if not f then return "" end
    local out = f:read("*a"); f:close(); return out
end
function try(t)
    local fn = t[1] or t
    local ok, r = pcall(fn)
    if ok then return r end
    return nil
end

-- import() resolves the two modules hostlib asks for.
local _stub_log = {
    info = function(fmt, ...) print("[info] " .. string.format(fmt, ...)) end,
    warn = function(fmt, ...) print("[warn] " .. string.format(fmt, ...)) end,
}
local _loaded = {}
function import(name)
    if name == "xim.libxpkg.log" then log = _stub_log; return _stub_log end
    error("unexpected import: " .. name)
end

-- ── the fake host ──────────────────────────────────────────────────────
-- ldconfig is shadowed: the harness must decide what the loader's index says.
-- Written as a real command on PATH because that is how hostlib asks.
local fake_bin = ROOT .. "/fake-bin"
os.execute(string.format('mkdir -p "%s"', fake_bin))

local function write_ldconfig(body)
    local f = assert(io.open(fake_bin .. "/ldconfig", "w"))
    f:write("#!/bin/sh\n", body, "\n")
    f:close()
    os.execute(string.format('chmod +x "%s/ldconfig"', fake_bin))
end

local ok_count, fail_count = 0, 0
local function check(name, got, want)
    if got == want then
        print(string.format("  ok   %s -> %s", name, tostring(got)))
        ok_count = ok_count + 1
    else
        print(string.format("  FAIL %s -> got %s, want %s",
                            name, tostring(got), tostring(want)))
        fail_count = fail_count + 1
    end
end

-- ── load the module under test ─────────────────────────────────────────
local hostlib = assert(loadfile(os.getenv("HOSTLIB")))()

print("== 1. ELF class is read from the file, not guessed ==")
check("elf_class(64-bit)", hostlib.elf_class(ROOT .. "/usr/lib64/libFoo.so.1"), 64)
check("elf_class(32-bit)", hostlib.elf_class(ROOT .. "/usr/lib/libFoo.so.1"), 32)
check("elf_class(text file)", hostlib.elf_class(ROOT .. "/usr/lib/notelf.so"), nil)
check("elf_class(missing)", hostlib.elf_class(ROOT .. "/nope.so"), nil)

print("== 2. biarch host, ldconfig lists BOTH ABIs (the #352 shape) ==")
-- 32-bit line FIRST, exactly as a biarch ldconfig may order them: taking the
-- first line is how an authoritative source yields a wrong answer.
write_ldconfig(string.format([[
cat <<'EOF'
	libFoo.so.1 (libc6) => %s/usr/lib/libFoo.so.1
	libFoo.so.1 (libc6,x86-64) => %s/usr/lib64/libFoo.so.1
EOF]], ROOT, ROOT))
check("dir_of via ldconfig", hostlib.dir_of("libFoo.so.1"),
      ROOT .. "/usr/lib64")

print("== 3. no ldconfig at all: fallback must still refuse the 32-bit dir ==")
write_ldconfig("exit 1")
-- The fallback list is absolute (/usr/lib64, /usr/lib), so it cannot see the
-- fake root. extra_dirs is how a caller names a layout only it knows -- and it
-- is ELF-class checked too, which is the assertion here: /usr/lib comes first
-- in the list and must still lose.
check("extra_dirs rejects 32-bit", hostlib.dir_of("libFoo.so.1", {
          extra_dirs = { ROOT .. "/usr/lib", ROOT .. "/usr/lib64" } }),
      ROOT .. "/usr/lib64")

print("== 4. absent soname is nil, not a guess ==")
check("dir_of(absent)", hostlib.dir_of("libNope.so.9"), nil)

print("== 5. entries_with_prefix drops 32-bit siblings ==")
-- The biarch trap one level in: a 64-bit directory that also holds a 32-bit
-- file with a matching name. Linking that into a payload fails at load.
local got = hostlib.entries_with_prefix(ROOT .. "/mixed", { "^libnvidia%-" })
table.sort(got)
check("mixed dir count", #got, 1)
check("mixed dir picks 64-bit", got[1], "libnvidia-glcore.so.550")

print("== 6. a dangling symlink is dropped, not counted ==")
local got2 = hostlib.entries_with_prefix(ROOT .. "/dangling", { "^libnvidia%-" })
check("dangling dropped", #got2, 0)

print()
if fail_count == 0 then
    print(string.format("PASS: %d assertions", ok_count))
    os.exit(0)
else
    print(string.format("FAIL: %d failed, %d passed", fail_count, ok_count))
    os.exit(1)
end
