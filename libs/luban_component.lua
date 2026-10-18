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
--   luban_component.config(programs, shares)
--   luban_component.uninstall(programs)

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

function M.config(programs, shares)
    local binding = pkginfo.name() .. "@" .. pkginfo.version()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    -- The package itself (a program of the same name is it), then what is bound to it.
    local named = false
    for _, p in ipairs(programs or {}) do named = named or p == pkginfo.name() end
    xvm.add(pkginfo.name(), named and { bindir = bindir } or nil)
    for _, p in ipairs(programs or {}) do
        if p ~= pkginfo.name() then xvm.add(p, { bindir = bindir, binding = binding }) end
    end
    -- File by file: a directory placed whole is one package's, and two
    -- desktops' sessions share share/wayland-sessions.
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
