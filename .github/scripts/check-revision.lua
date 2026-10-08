#!/usr/bin/env lua
--
-- A published version entry changes what it installs only together with a
-- higher `revision` (docs/V2/xpackage-spec.md, "`revision`").
--
-- WHAT IS CHECKED
-- ---------------
-- Every recipe that the change adds or modifies under pkgs/ is loaded twice
-- in the recipe sandbox (recipe-sandbox.lua): as it is on the base ref and as
-- it is in the work tree (or on --head). For each version entry the base
-- already has, in every `xpm` platform section:
--
--   * its effective URL, mirrors and digest are compared for each previously
--     supported architecture. Equivalent scalar/per-arch shapes, new
--     architectures and adding a complete digest to an unchanged URL preserve
--     existing payload identity;
--   * if the resource differs, the head's revision must be HIGHER than the
--     base's. A client that implements revision reinstalls a payload whose
--     recorded revision differs from the recipe's; one whose revision did not
--     move keeps the old bytes and never learns that the entry now means
--     something else;
--   * the revision must never decrease.
--
-- For every version entry in a changed recipe, new ones included, `revision`
-- must be a non-negative integer when present, must sit on the version entry
-- itself (not inside a per-arch map, where no client reads it), and must not
-- appear on a `ref` alias, which carries none.
--
-- Unknown resource fields remain part of identity. Platform/root sources,
-- proven Linux official coordinates and architecture aliases are normalized
-- before comparison. Replacing or removing a published digest changes its
-- identity; adding a valid digest to the same URL strengthens its integrity.
--
-- WHAT IS NOT CHECKED
-- -------------------
-- Hook changes. An install() that now writes different files under an
-- unchanged resource changes what the entry installs just as a new asset
-- does, and needs a higher revision just the same; whether a hook change
-- alters the installed files is a judgement this check cannot make, so it is
-- made in review.
--
-- An entry that is removed, or that is an alias on either side, is not
-- compared.
--
-- USAGE
-- -----
-- CI runs it through check-revision.sh, which finds the interpreter and the
-- base ref. Directly:
--
--     lua check-revision.lua --base <ref> [--head <ref>] [<repo-root>]
--
-- Exit 0 = every compared entry is consistent; 1 = a violation or a recipe
-- that cannot be loaded; 2 = usage error or an unusable base ref.
--

local SCRIPT_DIR = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local sandbox = dofile(SCRIPT_DIR .. "/recipe-sandbox.lua")
local sorted_keys = sandbox.sorted_keys

-- `math.type` separates 1 from 1.0, which is the distinction the client
-- makes: libxpkg reads a revision with lua_isinteger, so `revision = 1.0`
-- installs as revision 0.
if not math.type then
    io.stderr:write("check-revision.lua needs Lua 5.3+ (math.type)\n")
    os.exit(2)
end

-- Fields of a platform section that are not version entries.
local PLATFORM_FIELDS = {
    deps = true, exports = true, source = true, url_template = true,
    arch_alias = true, res_versioned = true, ref = true,
}
-- Fields of `xpm` that are not platform sections.
local XPM_FIELDS = { source = true }
-- Fields of a version entry that are not part of what it downloads.
local NON_RESOURCE = { revision = true, ref = true, deps = true }

-- ── git ────────────────────────────────────────────────────────────────
local function sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Output of a git command, and whether it exited 0.
local function git(root, args)
    local p = io.popen("git -C " .. sh_quote(root) .. " " .. args .. " 2>/dev/null")
    if not p then return "", false end
    local out = p:read("a") or ""
    local ok = p:close()
    return out, ok == true
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

-- ── values ─────────────────────────────────────────────────────────────
-- A canonical text form of a value: table keys sorted, strings quoted, 1 and
-- 1.0 kept apart. Two entries have the same resource exactly when their
-- canonical forms are equal.
local function canon(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        return (math.type(v) == "integer") and tostring(v) or string.format("%.17g(float)", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        if v == sandbox.stub then return "<stub>" end
        if depth > 32 then return "<too deep>" end
        local parts = {}
        for _, k in ipairs(sorted_keys(v)) do
            parts[#parts + 1] = "[" .. canon(k, depth + 1) .. "]="
                .. canon(rawget(v, k), depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

local function show(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)   -- 5.3+: a float prints as `1.0`, an integer as `1`
end

local function is_alias(entry)
    return type(entry) == "table" and rawget(entry, "ref") ~= nil
end

-- Compare the resource each existing architecture actually selects. Recipe
-- shape and newly supported architectures do not change an installed payload.
local ARCH_ALIASES = { arm64 = "aarch64", amd64 = "x86_64", x64 = "x86_64" }
local ARCH_NAMES = { x86_64=true, aarch64=true, arm64=true, x86=true,
    arm=true, armv7=true, riscv64=true, ppc64le=true, loongarch64=true }
local function normalized_arch(arch) return ARCH_ALIASES[arch] or arch end

local function arch_map(entry)
    local out = {}
    if type(entry) == "table" then
        for key, value in pairs(entry) do
            if ARCH_NAMES[key] and type(value) == "table" then
                local selected = {}
                for parent, item in pairs(entry) do
                    if not ARCH_NAMES[parent] and not NON_RESOURCE[parent] then
                        selected[parent] = item
                    end
                end
                for child, item in pairs(value) do selected[child] = item end
                out[normalized_arch(key)] = selected
            end
        end
    end
    return next(out) and out or nil
end

local function resource_archs(entry, pkg, platform)
    local mapped = arch_map(entry)
    if mapped then return mapped end
    local out = {}
    local url = type(entry) == "table" and entry.url or entry
    if type(url) == "table" then url = url.GLOBAL or url.CN end
    local named_arch = type(url) == "string" and url:match("%-" .. platform .. "%-([%w_]+)%.")
    if named_arch and ARCH_NAMES[named_arch] then
        out[normalized_arch(named_arch)] = entry
        return out
    end
    for _, arch in ipairs(type(pkg.archs) == "table" and pkg.archs or {}) do
        out[normalized_arch(arch)] = entry
    end
    if not next(out) then out.x86_64 = entry end
    return out
end

local function effective_resource(entry, pkg, platform, version, arch)
    local pdata = pkg.xpm[platform]
    local value = type(entry) == "table" and entry or { url = entry }
    local aliases = value.arch_alias or pdata.arch_alias or {}
    local alias = type(aliases) == "table" and aliases[arch] or nil
    local ext = platform == "windows" and "zip" or platform == "linux" and "tar.gz" or nil
    local function expand(url)
        local replacements = { name=pkg.name, version=version, os=platform,
            arch=arch, arch_alias=alias or arch, ext=ext }
        return (url:gsub("%${([%w_]+)}", function(key)
            return replacements[key] or "${" .. key .. "}"
        end))
    end
    local url = value.url
    local source = pdata.source or pkg.xpm.source
    if not url or url == "" then url = source end
    if (value.res == true and not value.url) or url == "XLINGS_RES" or url == "xlings-res" then
        -- The legacy Linux convention is fixed by the published resources.
        -- Other platforms may choose formats at download time; retain their
        -- official source token rather than assume an equivalent explicit URL.
        if platform == "linux" then
            local stem = pkg.name .. "-" .. version .. "-" .. platform .. "-" .. (alias or arch) .. ".tar.gz"
            local relative = pkg.name .. "/releases/download/" .. version .. "/" .. stem
            url = { GLOBAL = "https://github.com/xlings-res/" .. relative,
                    CN = "https://gitcode.com/xlings-res/" .. relative }
        else
            url = { official=true, platform=platform, arch=alias or arch }
        end
    elseif type(url) == "string" then
        url = expand(url)
    elseif type(url) == "table" then
        local urls = {}
        for region, address in pairs(url) do
            urls[region] = type(address) == "string" and expand(address) or address
        end
        url = urls
    end
    local hash = value.sha256 or value.sha256_by_arch
    if type(hash) == "table" then hash = hash[arch] or hash[alias] end
    local extra = {}
    for key, item in pairs(value) do
        if not NON_RESOURCE[key] and key ~= "url" and key ~= "sha256"
           and key ~= "sha256_by_arch" and key ~= "res" and key ~= "arch_alias" then
            extra[key] = item
        end
    end
    return { url=canon(url), hash=hash, extra=canon(extra) }
end

local function resource_changed(old, new, base_pkg, head_pkg, platform, version)
    local before = resource_archs(old, base_pkg, platform)
    local after = resource_archs(new, head_pkg, platform)
    local old_url = type(old) == "table" and old.url or old
    local old_source = base_pkg.xpm[platform].source or base_pkg.xpm.source
    local old_official = not arch_map(old) and
        (old_url == "XLINGS_RES" or old_url == "xlings-res"
         or (not old_url and (old_source == "xlings-res" or old_source == "XLINGS_RES"
              or type(old) == "table" and old.res == true)))
    for arch, resource in pairs(before) do
        if after[arch] ~= nil then
            local a = effective_resource(resource, base_pkg, platform, version, arch)
            local b = effective_resource(after[arch], head_pkg, platform, version, arch)
            if a.url ~= b.url or a.extra ~= b.extra then return true end
            if a.hash ~= b.hash then
                -- Adding a complete digest to an unchanged URL strengthens
                -- identity. Replacing or removing an existing digest changes it.
                if a.hash ~= nil or type(b.hash) ~= "string"
                   or #b.hash ~= 64 or not b.hash:match("^[0-9a-fA-F]+$") then
                    return true
                end
            end
        elseif not old_official then
            -- A finite published resource map loses a usable coordinate.
            -- Legacy official source tokens are parametric (Open in xlings),
            -- so narrowing those records does not prove a payload was removed.
            return true
        end
    end
    return false
end

-- The revision a client reads (non-negative integer, else 0), and the
-- problems with how it is stated.
local function revision_of(entry)
    if type(entry) ~= "table" then return 0, {} end
    local problems = {}
    local r = rawget(entry, "revision")
    local value = 0
    if r ~= nil then
        if math.type(r) == "integer" and r >= 0 then
            value = r
        else
            problems[#problems + 1] = string.format(
                "`revision = %s` is not a non-negative integer; a client reads it as 0",
                show(r))
        end
        if is_alias(entry) then
            problems[#problems + 1] =
                "a `ref` alias carries no revision; state it on the entry the alias names"
        end
    end
    for k, v in pairs(entry) do
        if type(v) == "table" and v ~= sandbox.stub and rawget(v, "revision") ~= nil then
            problems[#problems + 1] = string.format(
                "`revision` inside `%s` is read by no client; it belongs on the version entry",
                tostring(k))
        end
    end
    return value, problems
end

-- platform -> version -> entry, for every version entry of a loaded package.
local function entries_of(pkg)
    local out = {}
    local xpm = type(pkg) == "table" and rawget(pkg, "xpm") or nil
    if type(xpm) ~= "table" then return out end
    for _, plat in ipairs(sorted_keys(xpm)) do
        local pdata = rawget(xpm, plat)
        if type(pdata) == "table" and not XPM_FIELDS[plat] then
            local section = {}
            for _, key in ipairs(sorted_keys(pdata)) do
                if type(key) == "string" and not PLATFORM_FIELDS[key] then
                    section[key] = rawget(pdata, key)
                end
            end
            out[tostring(plat)] = section
        end
    end
    return out
end

-- ── the check ──────────────────────────────────────────────────────────
local function usage()
    io.stderr:write("usage: check-revision.lua --base <ref> [--head <ref>] [<repo-root>]\n")
    os.exit(2)
end

local base_ref, head_ref, root = nil, nil, "."
local i = 1
while arg[i] do
    local a = arg[i]
    if a == "--base" then base_ref = arg[i + 1]; i = i + 2
    elseif a == "--head" then head_ref = arg[i + 1]; i = i + 2
    elseif a:sub(1, 2) == "--" then usage()
    else root = a; i = i + 1 end
end
if not base_ref or base_ref == "" then usage() end
root = root:gsub("/+$", "")
if root == "" then root = "/" end

local _, base_ok = git(root, "rev-parse --verify --quiet " .. sh_quote(base_ref .. "^{commit}"))
if not base_ok then
    io.stderr:write(string.format("check-revision: cannot resolve the base ref '%s'\n", base_ref))
    os.exit(2)
end

local diff_args = "diff --name-only --no-renames --diff-filter=AM " .. sh_quote(base_ref)
if head_ref then diff_args = diff_args .. " " .. sh_quote(head_ref) end
local names, diff_ok = git(root, diff_args .. " -- pkgs/")
if not diff_ok then
    io.stderr:write("check-revision: git diff failed\n")
    os.exit(2)
end

local changed = {}
for line in names:gmatch("[^\n]+") do
    if line:match("%.lua$") then changed[#changed + 1] = line end
end
table.sort(changed)

local errors, notes = {}, {}
local compared, validated = 0, 0

local function err(file, msg)
    errors[#errors + 1] = string.format("::error file=%s::%s", file, msg)
end

for _, file in ipairs(changed) do
    local head_text
    if head_ref then
        local out, ok = git(root, "show " .. sh_quote(head_ref .. ":" .. file))
        head_text = ok and out or nil
    else
        head_text = read_file(root .. "/" .. file)
    end
    local head_pkg, head_err
    if head_text then
        head_pkg, head_err = sandbox.load_recipe_text(head_text, file)
    else
        head_err = "cannot read the file"
    end
    if not head_pkg then
        err(file, "cannot load recipe: " .. tostring(head_err))
    else
        local base_pkg = nil
        local base_text, on_base = git(root, "show " .. sh_quote(base_ref .. ":" .. file))
        if on_base then
            local base_err
            base_pkg, base_err = sandbox.load_recipe_text(base_text, file .. "@base")
            if not base_pkg then
                notes[#notes + 1] = string.format(
                    "%s: the base version does not load (%s); its entries were not compared",
                    file, tostring(base_err))
            end
        end

        local head_entries = entries_of(head_pkg)
        local base_entries = entries_of(base_pkg)

        for _, plat in ipairs(sorted_keys(head_entries)) do
            local section = head_entries[plat]
            for _, ver in ipairs(sorted_keys(section)) do
                local entry = section[ver]
                local where = string.format("%s xpm.%s[%q]", file, plat, ver)
                validated = validated + 1
                local head_rev, problems = revision_of(entry)
                for _, p in ipairs(problems) do err(file, where .. ": " .. p) end

                local old = base_entries[plat] and base_entries[plat][ver]
                if old ~= nil and not is_alias(old) and not is_alias(entry) then
                    compared = compared + 1
                    local base_rev = revision_of(old)
                    if head_rev < base_rev then
                        err(file, string.format(
                            "%s: revision decreased from %d to %d. A revision only ever "
                            .. "increases; a client holding revision %d would take the "
                            .. "entry for a different payload and reinstall it.",
                            where, base_rev, head_rev, base_rev))
                    elseif resource_changed(old, entry, base_pkg, head_pkg, plat, ver)
                       and head_rev <= base_rev then
                        err(file, string.format(
                            "%s: the resource of a published version changed while its "
                            .. "revision stayed %d. A published url and sha256 are "
                            .. "immutable; publish the new payload under a new asset name "
                            .. "and raise `revision` to %d, so that clients holding "
                            .. "revision %d reinstall it (docs/V2/xpackage-spec.md).",
                            where, base_rev, base_rev + 1, base_rev))
                    end
                end
            end
        end

        for _, plat in ipairs(sorted_keys(base_entries)) do
            for _, ver in ipairs(sorted_keys(base_entries[plat])) do
                if not (head_entries[plat] and head_entries[plat][ver] ~= nil) then
                    notes[#notes + 1] = string.format(
                        "%s xpm.%s[%q]: removed; not compared", file, plat, ver)
                end
            end
        end
    end
end

for _, n in ipairs(notes) do io.write("note: " .. n .. "\n") end
for _, e in ipairs(errors) do io.write(e .. "\n") end

if #errors > 0 then
    io.write(string.format(
        "revision check: FAIL (%d problem(s); %d published entr%s compared, "
        .. "%d entr%s validated, %d changed recipe(s) against %s)\n",
        #errors, compared, compared == 1 and "y" or "ies",
        validated, validated == 1 and "y" or "ies", #changed, base_ref))
    os.exit(1)
end
-- The counts are part of the result: a check that compared nothing prints
-- the same PASS as one that compared everything, and only the numbers tell
-- the two apart.
io.write(string.format(
    "revision check: PASS (%d published entr%s compared, %d entr%s validated, "
    .. "%d changed recipe(s) against %s)\n",
    compared, compared == 1 and "y" or "ies",
    validated, validated == 1 and "y" or "ies", #changed, base_ref))
os.exit(0)
