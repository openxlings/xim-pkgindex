-- A Luban desktop component (xlings: 2026-10-18 Luban OS distribution design
-- §4.6, §6.3): a package whose payload is one tree -- bin/, libexec/<name>/,
-- etc/, share/ -- built by tools/res/build.sh, or written by its recipe.
-- What makes it a desktop is a convention, not a field: it places
-- share/wayland-sessions/<id>.desktop. A terminal places
-- share/xdg-terminals/<id>.desktop; checks go in share/luban/checks.d.
--
-- In a Luban system the root projects the payload's bin/, share/ and
-- libexec/<name>/ into /usr; in any other SubOS these declarations place the
-- programs and the shared files.
--
--   luban_component.install(must)        the payload into place; `must`: files it has to hold
--   luban_component.config(programs, shares, checks)
--                                        `checks`: the recipe's extensions.luban.checks,
--                                        written to share/luban/checks.d/<name>.json
--                                        (xlings design 2026-10-21 §6.1)
--   luban_component.uninstall(programs)
--
-- A tree's own musl loader searches only the tree: an empty
-- libexec/<name>/etc/ld-musl-<arch>.path beside it (musl reads it there) takes
-- away the default /lib:/usr/local/lib:/usr/lib -- a Luban system's /usr/lib
-- is glibc's, and a library dlopen()ed from there (libvulkan) crashes the
-- program (xlings design 2026-10-21 J12).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")

local M = {}

function M.install(must)
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    for _, rel in ipairs(must or {}) do
        if not os.isfile(path.join(dir, rel)) then return false end
    end
    return true
end

-- A value as JSON: what a check holds (strings, numbers, booleans).
local function json_(v)
    if type(v) == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif type(v) == "number" or type(v) == "boolean" then
        return tostring(v)
    end
    return "null"
end

-- The recipe's checks, where a system's self-check reads them.
function M.write_checks(checks)
    if not checks or #checks == 0 then return nil end
    local parts = {}
    for _, c in ipairs(checks) do
        local keys = {}
        for k in pairs(c) do table.insert(keys, k) end
        table.sort(keys)
        local fields = {}
        for _, k in ipairs(keys) do table.insert(fields, json_(k) .. ": " .. json_(c[k])) end
        table.insert(parts, "{" .. table.concat(fields, ", ") .. "}")
    end
    local rel = path.join("share", "luban", "checks.d", pkginfo.name() .. ".json")
    local file = path.join(pkginfo.install_dir(), rel)
    os.mkdir(path.directory(file))
    io.writefile(file, '{"checks": [' .. table.concat(parts, ", ") .. "]}\n")
    return rel
end

-- Every loader the tree holds, its path file beside it (empty: nothing but
-- the tree's own libraries, which its programs name).
function M.close_loaders()
    for _, tree in ipairs(os.dirs(path.join(pkginfo.install_dir(), "libexec", "*")) or {}) do
        for _, ldso in ipairs(fs.files(path.join(tree, "lib")) or {}) do
            local arch = path.filename(ldso):match("^ld%-musl%-(.+)%.so%.1$")
            local file = arch and path.join(tree, "etc", "ld-musl-" .. arch .. ".path")
            if file and not os.isfile(file) then
                os.mkdir(path.directory(file))
                io.writefile(file, "")
            end
        end
    end
end

function M.config(programs, shares, checks)
    M.close_loaders()
    local binding = pkginfo.name() .. "@" .. pkginfo.version()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    -- The package itself (a program of the same name is it), then what is bound to it.
    local named = false
    for _, p in ipairs(programs or {}) do named = named or p == pkginfo.name() end
    xvm.add(pkginfo.name(), named and { bindir = bindir } or nil)
    for _, p in ipairs(programs or {}) do
        if p ~= pkginfo.name() then xvm.add(p, { bindir = bindir, binding = binding }) end
    end
    local written = M.write_checks(checks)
    -- File by file: a directory placed whole is one package's, and two
    -- desktops' sessions share share/wayland-sessions.
    if xvm.files and written then xvm.files{ src = written, dst = written, binding = binding } end
    if xvm.files then
        local root = pkginfo.install_dir()
        for _, rel in ipairs(shares or {}) do
            local files = fs.files(path.join(root, rel), true) or {}
            table.sort(files)
            for _, f in ipairs(files) do
                local name = f:sub(#root + 2)
                xvm.files{ src = name, dst = name, binding = binding }
            end
        end
    end
    return true
end

function M.uninstall(programs)
    for _, p in ipairs(programs or {}) do
        if p ~= pkginfo.name() then xvm.remove(p) end
    end
    xvm.remove(pkginfo.name())
    return true
end

return M
