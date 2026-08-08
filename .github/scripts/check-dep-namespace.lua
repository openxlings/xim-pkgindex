#!/usr/bin/env lua
--
-- Structural reader for the `deps` declarations in this index, plus the
-- namespace policy check built on top of it.
--
-- WHY LUA AND NOT A REGEX
-- -----------------------
-- A dep list is not a line. It spans several lines, it appears under more
-- than one `xpm.<platform>` section, it appears again inside individual
-- version entries, and it has two legal shapes:
--
--     deps = { "a", "b" }                          -- positional
--     deps = { runtime = { "a" }, build = { "b" } }
--
-- A line sweep therefore both MISSES entries (a name on a continuation line
-- under a section it never looked at) and MIS-ATTRIBUTES them (the name is
-- real, the platform reported next to it is not). Both failures read as a
-- clean result. So the recipe is loaded as Lua -- the same text the client
-- loads -- and `package.xpm` is walked as a table. What comes out is one row
-- per (file, platform, version-scope, kind, index, dep) with the real value.
--
-- The recipe is loaded in a sandbox: hook bodies never run (loading a chunk
-- does not call its functions), and the top-level `import(...)` calls the
-- recipes make resolve to a permissive stub, so no libxpkg is required.
--
-- USAGE
-- -----
-- Run it through the wrapper, which is what CI does:
--
--     .github/scripts/check-dep-namespace.sh
--
-- Directly, when you want the enumeration itself:
--
--     lua .github/scripts/check-dep-namespace.lua --list  [<root>]
--     lua .github/scripts/check-dep-namespace.lua --check [<root>]
--
-- --list writes `file<TAB>platform<TAB>scope<TAB>kind<TAB>index<TAB>dep`,
-- sorted. That is the form to diff before against after when editing dep
-- lists: a text edit to a `.lua` recipe still parses and can mean something
-- else, and only the structured dump says whether it does.
--
-- --check fails when a dep name carries NO namespace while a package of that
-- name exists in this index. Such a name resolves fine only while exactly one
-- index provides it; as soon as a second one does -- and CI registers every
-- CHANGED recipe a second time under `local:` -- resolution reports
-- `package '<name>' is ambiguous` and the install stops. That is a property of
-- the changed set, not of the recipe, which is why these stay latent until an
-- unrelated PR happens to touch both packages at once. 2026-08-08: 66 of them
-- across 26 recipes, surfaced by one accidental collision on fontconfig.
--
-- A bare name that matches NO package here is reported as a note and not
-- failed: it is a different defect (or a reference this index cannot see), and
-- this check has no evidence about which.
--

local ROOT = "."

-- ── the one exemption, and its expiry date ─────────────────────────────
-- The rule inverts for a package that does not exist YET. A PR that adds
-- package P and a consumer of P in the same change has P only under `local`,
-- and `xim:P` resolves from the `xim` namespace alone -- so the prefix makes a
-- new package undepend-able by its own PR (`package 'xim:P' not found`; hit in
-- #498 and again in #540). The bare name is correct there, and correct only
-- until P is published, at which point the ambiguity above starts applying
-- instead.
--
-- So: list the (recipe, dep-name) pair here, in the SAME PR that adds the new
-- package, and REMOVE it in the follow-up that lands after publication. An
-- entry left behind is the bug this check exists to catch, wearing a permit --
-- which is why the list carries the PR that added it, and why it is expected
-- to be empty most of the time.
local EXEMPT = {
    -- ["pkgs/g/godot.lua"] = { ["graphics"] = "#540, remove once published" },
    ["pkgs/x/xmake.lua"] = { ["ncurses"] = "#582, new in this PR; remove once published" },
}

local function is_exempt(file, name)
    local entry = EXEMPT[file]
    return entry ~= nil and entry[name] ~= nil
end

-- ── the sandbox ────────────────────────────────────────────────────────
-- A value that tolerates being indexed, called, iterated and printed, so
-- top-level recipe statements (`import("xim.libxpkg.pkginfo")`, and the
-- occasional `local x = something.y`) neither fail nor reach anything real.
local stub
stub = setmetatable({}, {
    __index    = function() return stub end,
    __newindex = function() end,
    __call     = function() return stub end,
    __concat   = function() return "" end,
    __tostring = function() return "" end,
    __len      = function() return 0 end,
})

local function sandbox_env()
    -- os/io are handed out as safe subsets: a recipe may legitimately read
    -- os.getenv at load time, but nothing here may execute or delete.
    local safe_os = setmetatable(
        { time = os.time, date = os.date, clock = os.clock, getenv = os.getenv },
        { __index = function() return stub end })
    local safe_io = setmetatable({}, { __index = function() return stub end })

    local base = {
        assert = assert, error = error, ipairs = ipairs, pairs = pairs,
        next = next, pcall = pcall, xpcall = xpcall, select = select,
        tonumber = tonumber, tostring = tostring, type = type,
        rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
        setmetatable = setmetatable, getmetatable = getmetatable,
        unpack = table.unpack, print = function() end,
        string = string, table = table, math = math,
        os = safe_os, io = safe_io,
    }
    local env = {}
    setmetatable(env, {
        __index = function(_, k)
            local v = base[k]
            if v ~= nil then return v end
            return stub
        end,
    })
    return env
end

-- Load one recipe and return the `package` table it declares (or nil, err).
-- Running the chunk executes only its top level: the install/config/uninstall
-- hooks are defined, never called.
local function load_recipe(file)
    local env = sandbox_env()
    local chunk, err = loadfile(file, "t", env)
    if not chunk then return nil, "parse error: " .. tostring(err) end
    local ok, rerr = pcall(chunk)
    if not ok then return nil, "load error: " .. tostring(rerr) end
    local pkg = rawget(env, "package")
    if type(pkg) ~= "table" then return nil, "no `package` table" end
    return pkg, nil
end

-- ── walking ────────────────────────────────────────────────────────────
local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- Append every dep of `deps` to `out`, tagging each with its shape.
--   positional -> kind "list"    (the client copies it into BOTH runtime and build)
--   runtime=   -> kind "runtime"
--   build=     -> kind "build"
local function collect_deps(deps, platform, scope, out)
    if type(deps) == "string" then
        out[#out + 1] = { platform = platform, scope = scope, kind = "list", index = 1, dep = deps }
        return
    end
    if type(deps) ~= "table" then return end

    for i, v in ipairs(deps) do
        if type(v) == "string" then
            out[#out + 1] = { platform = platform, scope = scope, kind = "list", index = i, dep = v }
        end
    end
    for _, kind in ipairs({ "build", "runtime" }) do
        local sub = rawget(deps, kind)
        if type(sub) == "string" then
            out[#out + 1] = { platform = platform, scope = scope, kind = kind, index = 1, dep = sub }
        elseif type(sub) == "table" then
            for i, v in ipairs(sub) do
                if type(v) == "string" then
                    out[#out + 1] = { platform = platform, scope = scope, kind = kind, index = i, dep = v }
                end
            end
        end
    end
end

-- Every dep declaration reachable from a loaded `package` table.
local function walk_package(pkg)
    local out = {}
    if type(pkg) ~= "table" then return out end

    -- A descriptor-level `deps` (outside xpm) applies to every platform.
    collect_deps(rawget(pkg, "deps"), "*", "-", out)

    local xpm = rawget(pkg, "xpm")
    if type(xpm) == "table" then
        for _, plat in ipairs(sorted_keys(xpm)) do
            local pdata = rawget(xpm, plat)
            if type(pdata) == "table" then
                collect_deps(rawget(pdata, "deps"), tostring(plat), "-", out)
                -- version entries: `["latest"]`, `["2.15.0"]`, ...
                for _, vkey in ipairs(sorted_keys(pdata)) do
                    if vkey ~= "deps" then
                        local vdata = rawget(pdata, vkey)
                        if type(vdata) == "table" then
                            collect_deps(rawget(vdata, "deps"), tostring(plat), tostring(vkey), out)
                        end
                    end
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.platform ~= b.platform then return a.platform < b.platform end
        if a.scope ~= b.scope then return a.scope < b.scope end
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.index ~= b.index then return a.index < b.index end
        return a.dep < b.dep
    end)
    return out
end

-- ── the index ──────────────────────────────────────────────────────────
local function popen_lines(cmd)
    local lines = {}
    local p = io.popen(cmd)
    if not p then return lines end
    for line in p:lines() do lines[#lines + 1] = line end
    p:close()
    return lines
end

local function recipe_files(root)
    return popen_lines(string.format(
        "find '%s/pkgs' -type f -name '*.lua' 2>/dev/null | sort", root))
end

-- Paths are reported relative to the index root, so output is the same
-- whether the check runs from the repo or from a copy of it.
local function rel_to(root, file)
    local pattern = "^" .. root:gsub("(%W)", "%%%1") .. "/"
    return (file:gsub(pattern, ""):gsub("^%./", ""))
end

local function count_recipes(root)
    return #recipe_files(root)
end

-- name -> relative path, for every package this index provides.
local function index_packages(root)
    local set = {}
    for _, f in ipairs(recipe_files(root)) do
        local name = f:match("([^/]+)%.lua$")
        if name then set[name] = rel_to(root, f) end
    end
    return set
end

-- name -> { ns = <declared namespace or nil>, plats = { linux = true, ... } }
--
-- Both facts come from loading the recipe, and both are needed to tell a
-- correct dep from one that merely looks correct:
--
--   * `namespace = "config"` on the provider means `xim:<name>` names nothing.
--     `config:rustup-mirror` is a real package; `xim:rustup-mirror` is not.
--   * a provider with no section for the platform doing the depending cannot
--     satisfy it there, whatever prefix is on the front.
local function index_facts(root)
    local facts = {}
    for _, f in ipairs(recipe_files(root)) do
        local name = f:match("([^/]+)%.lua$")
        local pkg = name and load_recipe(f) or nil
        if pkg then
            local plats = {}
            local xpm = rawget(pkg, "xpm")
            if type(xpm) == "table" then
                for k in pairs(xpm) do plats[tostring(k)] = true end
            end
            local ns = rawget(pkg, "namespace")
            facts[name] = { ns = (type(ns) == "string" and ns ~= "") and ns or nil,
                            plats = plats }
        end
    end
    return facts
end

-- Platform keys the client can actually select.
--
-- `detect_platform()` in xlings returns `build_os()`, which is one of these
-- three and nothing else -- so an `xpm.debian` or `xpm.ubuntu` section is never
-- chosen and a dep declared inside one cannot fail at install time. Reporting
-- those would be reporting on dead code, and a check with unfixable findings
-- gets ignored wholesale.
local SELECTABLE = { linux = true, macosx = true, windows = true }

-- ── the dep spec ───────────────────────────────────────────────────────
-- "xim:expat@2.6.2" -> namespace "xim", name "expat", version "2.6.2"
local function split_dep(dep)
    local namespace, rest = dep:match("^([%w_%-%.]+):(.*)$")
    if not namespace then rest = dep end
    local name = rest:match("^([^@]+)") or rest
    return namespace, name
end

-- ── modes ──────────────────────────────────────────────────────────────
local function each_row(root, fn)
    local bad = {}
    for _, file in ipairs(recipe_files(root)) do
        local rel = rel_to(root, file)
        local pkg, err = load_recipe(file)
        if not pkg then
            bad[#bad + 1] = { file = rel, err = err }
        else
            for _, row in ipairs(walk_package(pkg)) do
                row.file = rel
                fn(row)
            end
        end
    end
    return bad
end

local function mode_list(root)
    local bad = each_row(root, function(row)
        io.write(string.format("%s\t%s\t%s\t%s\t%d\t%s\n",
            row.file, row.platform, row.scope, row.kind, row.index, row.dep))
    end)
    for _, b in ipairs(bad) do
        io.stderr:write(string.format("!! %s: %s\n", b.file, b.err))
    end
    return #bad == 0 and 0 or 1
end

local function mode_check(root)
    local provided = index_packages(root)
    local facts = index_facts(root)
    local violations, unresolved, exempted = {}, {}, {}
    local wrong_ns, no_plat = {}, {}
    local seen = 0

    local bad = each_row(root, function(row)
        seen = seen + 1
        local namespace, name = split_dep(row.dep)
        local fact = facts[name]

        -- Checks that apply to a QUALIFIED dep. Both of these shipped as CI
        -- failures on this branch's first run, from a sweep that assumed every
        -- package is `xim:` and lives on every platform.
        if namespace and fact then
            local want = fact.ns or "xim"
            if namespace ~= want then
                wrong_ns[#wrong_ns + 1] = { row = row, name = name, want = want }
            end
            if SELECTABLE[row.platform] and next(fact.plats)
               and not fact.plats[row.platform] then
                no_plat[#no_plat + 1] = { row = row, name = name, plats = fact.plats }
            end
        end

        if namespace then return end
        if not provided[name] then
            unresolved[#unresolved + 1] = { row = row, name = name }
        elseif is_exempt(row.file, name) then
            exempted[#exempted + 1] = { row = row, name = name,
                                        why = EXEMPT[row.file][name] }
        else
            violations[#violations + 1] = { row = row, name = name, path = provided[name] }
        end
    end)

    for _, b in ipairs(bad) do
        io.stderr:write(string.format("::error file=%s::cannot load recipe: %s\n", b.file, b.err))
    end

    for _, v in ipairs(violations) do
        local r = v.row
        io.write(string.format(
            "::error file=%s::dep `%s` (xpm.%s%s, %s) is bare, but this index provides `%s` at %s. "
            .. "Write `xim:%s` -- a bare name resolves only while exactly one index offers it, and "
            .. "fails with \"package '%s' is ambiguous\" as soon as a second one does. If `%s` is "
            .. "NEW in this PR the bare name is correct for now; declare it in EXEMPT at the top of "
            .. "%s and remove that entry once it is published.\n",
            r.file, r.dep, r.platform,
            r.scope ~= "-" and ("." .. r.scope) or "", r.kind,
            v.name, v.path, r.dep, r.dep, v.name, "check-dep-namespace.lua"))
    end

    for _, v in ipairs(wrong_ns) do
        local r = v.row
        io.write(string.format(
            "::error file=%s::dep `%s` (xpm.%s%s) uses the wrong namespace. `%s` declares "
            .. "`namespace = \"%s\"`, so the package is `%s:%s` and `%s` names nothing at all.\n",
            r.file, r.dep, r.platform, r.scope ~= "-" and ("." .. r.scope) or "",
            v.name, v.want, v.want, v.name, r.dep))
    end

    for _, v in ipairs(no_plat) do
        local r = v.row
        local list = {}
        for p in pairs(v.plats) do list[#list + 1] = p end
        table.sort(list)
        io.write(string.format(
            "::error file=%s::dep `%s` is declared under xpm.%s%s, but `%s` has sections for "
            .. "[%s] only -- it cannot be resolved on %s. Drop the dep for this platform, or add "
            .. "a %s section to %s.\n",
            r.file, r.dep, r.platform, r.scope ~= "-" and ("." .. r.scope) or "",
            v.name, table.concat(list, ", "), r.platform, r.platform, v.name))
    end

    if #exempted > 0 then
        io.write(string.format("note: %d bare dep(s) exempted as not-yet-published:\n", #exempted))
        for _, e in ipairs(exempted) do
            io.write(string.format("  %s  %s  (%s)\n", e.row.file, e.row.dep, e.why))
        end
    end

    if #unresolved > 0 then
        -- Not a failure: a bare name with no package behind it in this index
        -- is a different defect (or an intentional cross-index reference),
        -- and this check has no evidence about which.
        io.write(string.format("note: %d bare dep(s) name no package in this index (not checked here):\n",
            #unresolved))
        for _, u in ipairs(unresolved) do
            io.write(string.format("  %s  xpm.%s%s  %s\n", u.row.file, u.row.platform,
                u.row.scope ~= "-" and ("." .. u.row.scope) or "", u.row.dep))
        end
    end

    if #bad > 0 or #violations > 0 or #wrong_ns > 0 or #no_plat > 0 then
        io.write(string.format(
            "xpkg dep check: FAIL (%d bare, %d wrong-namespace, %d platform-missing, "
            .. "%d unreadable recipe(s))\n",
            #violations, #wrong_ns, #no_plat, #bad))
        return 1
    end
    -- The count is part of the result on purpose. A check that read nothing
    -- prints the same "PASS" as one that read everything, and this repo has
    -- shipped that failure before (a green install-test that ran zero
    -- packages, #532). The number is what tells the two apart.
    io.write(string.format("xpkg dep namespace check: PASS (%d dep declaration(s) across %d recipes)\n",
        seen, count_recipes(root)))
    return 0
end

-- ── entry ──────────────────────────────────────────────────────────────
local mode = arg[1] or "--check"
ROOT = arg[2] or ROOT
ROOT = ROOT:gsub("/+$", "")
if ROOT == "" then ROOT = "/" end

if mode == "--list" then
    os.exit(mode_list(ROOT))
elseif mode == "--check" then
    os.exit(mode_check(ROOT))
else
    io.stderr:write("usage: check-dep-namespace.lua [--list|--check] [<repo-root>]\n")
    os.exit(2)
end
