-- Exercise libs/winpath.lua in a plain-Lua sandbox: no xmake, only what the
-- libxpkg prelude guarantees. The module needs nothing forged -- it is pure
-- string work -- so what is checked is the contract itself.

local LIB = assert(os.getenv("WINPATH_LIB"), "WINPATH_LIB required")

local winpath = assert(loadfile(LIB))()

local n = 0
local function check(cond, msg)
    if not cond then error("FAIL: " .. msg, 2) end
    n = n + 1
end
local function eq(got, want, msg)
    if got ~= want then error(string.format("FAIL: %s: got %q, want %q", msg, got, want), 2) end
    n = n + 1
end

-- the case the module exists for: a mixed-separator path
eq(winpath.native("C:/xlings/data/xpkgs/xim-x-winscp/6.7.1"),
   "C:\\xlings\\data\\xpkgs\\xim-x-winscp\\6.7.1", "forward slashes become backslashes")
eq(winpath.native("C:\\xlings/data/xpkgs"),
   "C:\\xlings\\data\\xpkgs", "a mixed path is normalised, separators only")
eq(winpath.native("C:\\xlings\\data"), "C:\\xlings\\data", "an already-native path is unchanged")

-- shapes that must survive
eq(winpath.native("bin/psql"), "bin\\psql", "a relative path stays relative")
eq(winpath.native("//server/share/file"), "\\\\server\\share\\file", "a UNC path stays UNC")
eq(winpath.native(""), "", "the empty path is unchanged")

-- a value that is not a string
eq(winpath.native(42), "42", "a number is stringified, not raised")

-- idempotence: converting twice cannot differ from converting once
local once = winpath.native("C:/a/b/c")
check(winpath.native(once) == once, "native is idempotent")

print(string.format("PASS: %d checks", n))
