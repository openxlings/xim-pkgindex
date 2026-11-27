-- Point a repacked payload's build-prefix placeholders at its install directory.
--
-- Loaded by package install() hooks via:
--     import("xim.pkgindex.relocate")
--
-- conda-forge builds every package in a padded placeholder prefix, and a
-- library that locates its own data at run time -- gtk3's module directory,
-- pocl's kernel sources -- keeps that prefix compiled in. Only the install
-- step can know the real directory, so this is the one thing about a
-- repacked payload that still happens in a hook.
--
-- WHICH files and WHICH placeholder is not decided here. The repack tool
-- (.agents/tools/repack/repack.py) audits every placeholder when it builds the
-- payload and writes the ones that must follow the install location into the
-- payload's own RELOCATE.json:
--
--     { "schema": 1,
--       "entries": [ { "path": "lib/libgtk-3.so.0.2411.32",
--                      "mode": "binary",
--                      "placeholder": "/home/conda/feedstock_root/.../_h_env_placehold_..." } ] }
--
-- so a recipe carries no placeholder constants, and a payload rebuilt from a
-- new upstream build brings its own. Paths the HOST owns (/etc, daemon
-- sockets) are rewritten by the tool, never here.
--
-- BINARY MODE keeps the file length: each NUL-terminated string that contains
-- the placeholder is rewritten and padded with NULs, so no ELF offset moves.
-- This is what conda's own installer does, and it is why the install
-- directory must not be longer than the placeholder (255 bytes in practice).
--
-- Fails closed: a missing manifest, a path outside the payload, a missing
-- file, or a placeholder that does not occur in its file (the upstream build
-- changed and the manifest did not) is an error, not a skipped entry.

import("xim.libxpkg.fs")
import("xim.libxpkg.json")

local relocate = {}

local function plain_count(data, needle)
    local n, pos = 0, 1
    while true do
        local s, e = data:find(needle, pos, true)
        if not s then return n end
        n, pos = n + 1, e + 1
    end
end

local function replace_plain(data, needle, repl)
    local out, pos, n = {}, 1, 0
    while true do
        local s, e = data:find(needle, pos, true)
        if not s then break end
        out[#out + 1] = data:sub(pos, s - 1)
        out[#out + 1] = repl
        pos, n = e + 1, n + 1
    end
    out[#out + 1] = data:sub(pos)
    return table.concat(out), n
end

-- Pure: returns DATA with every PLACEHOLDER replaced by PREFIX.
function relocate.rewrite(data, placeholder, prefix, binary)
    if not binary then return (replace_plain(data, placeholder, prefix)) end
    assert(#prefix <= #placeholder,
        "install directory is longer than the placeholder it replaces")
    local pad = #placeholder - #prefix
    local out, pos = {}, 1
    while true do
        local s = data:find(placeholder, pos, true)
        if not s then break end
        -- the whole NUL-terminated string that holds this occurrence
        local first = s
        while first > pos and data:byte(first - 1) ~= 0 do first = first - 1 end
        local term = data:find("\0", s, true)
        if not term then break end
        local str, n = replace_plain(data:sub(first, term - 1), placeholder, prefix)
        out[#out + 1] = data:sub(pos, first - 1)
        out[#out + 1] = str
        out[#out + 1] = string.rep("\0", n * pad + 1)
        pos = term + 1
    end
    out[#out + 1] = data:sub(pos)
    return table.concat(out)
end

-- Apply INSTALL_DIR/RELOCATE.json. Returns the number of entries applied.
function relocate.apply(install_dir, manifest)
    local file = install_dir .. "/" .. (manifest or "RELOCATE.json")
    local read, m = pcall(function() return json.decode(fs.read(file)) end)
    if not read then m = nil end
    if type(m) ~= "table" or m.schema ~= 1 or type(m.entries) ~= "table" then
        error("relocate: " .. file .. " is missing or not a schema-1 manifest")
    end
    for _, e in ipairs(m.entries) do
        local rel = e.path
        if type(rel) ~= "string" or rel:sub(1, 1) == "/" or rel:find("..", 1, true) then
            error("relocate: path outside the payload: " .. tostring(rel))
        end
        local target = install_dir .. "/" .. rel
        local present, data = pcall(fs.read, target)
        if not present then error("relocate: " .. rel .. " is listed but not in the payload") end
        if plain_count(data, e.placeholder) == 0 then
            error("relocate: " .. rel .. " does not contain its recorded placeholder")
        end
        local new = relocate.rewrite(data, e.placeholder, install_dir, e.mode == "binary")
        assert(e.mode ~= "binary" or #new == #data, "relocate: binary length changed for " .. rel)
        fs.write(target, new)
    end
    return #m.entries
end

return relocate
