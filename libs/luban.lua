-- Luban's packages in this index (xlings: Luban OS design part 2 §2.1).
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.luban")
--
-- An edition, a policy and a boot profile are DATA: what a root is made of,
-- what isolation compiles to, how an image boots. A recipe declares that data
-- and calls one function here; this is the only code that writes it. So a
-- recipe has nothing to review but its data, the static tests read the data
-- as it is published, and every edition writes its files the same way.
--
--   luban.edition({ id = "core", variant = "Core", versions = versions, files = files })
--       versions[v] = { manifest = <JSON text>, files = <files, optional> }
--       files       = { { "<path in the template>", <content>, <"755", optional> }, ... }
--     writes .xlings.json (the manifest, byte for byte), every file, and
--     usr/share/factory/etc/os-release. A version's own `files` replace the
--     recipe-wide ones. A version the recipe does not list is an error.
--   luban.policy(json)  -- policy.json, byte for byte
--   luban.boot(json)    -- share/luban/boot.json, byte for byte
--
-- A published version's output never changes: tests/fixtures/luban-published.json
-- holds the sha256 of every file each published version writes.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local luban = {}

local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function write(rel, content, mode)
    local file = pkginfo.install_dir() .. "/" .. rel
    os.mkdir(assert(file:match("^(.*)/[^/]+$")))
    local f = io.open(file, "wb")
    if not f then error("cannot write " .. file) end
    assert(f:write(content))
    f:close()
    if mode then
        if mode ~= "755" and mode ~= "644" then error("luban: mode " .. mode .. " for " .. rel) end
        system.exec("chmod " .. mode .. " " .. quote(file))
    end
end

local function fresh()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
end

function luban.os_release(id, variant, version)
    return string.format([[
NAME="Luban"
ID=luban
VARIANT="%s"
VARIANT_ID=%s
VERSION_ID=%s
PRETTY_NAME="Luban %s %s"
HOME_URL="https://github.com/openxlings/xlings"
]], variant, id, version, variant, version)
end

function luban.edition(spec)
    local version = pkginfo.version()
    local this = spec.versions[version]
    if not this then error(string.format("luban-%s: no manifest for %s", spec.id, tostring(version))) end
    fresh()
    write(".xlings.json", this.manifest)
    for _, f in ipairs(this.files or spec.files or {}) do write(f[1], f[2], f[3]) end
    write("usr/share/factory/etc/os-release", luban.os_release(spec.id, spec.variant, version))
    log.info("luban-%s template at %s", spec.id, pkginfo.install_dir())
    return true
end

function luban.policy(json)
    os.mkdir(pkginfo.install_dir())
    write("policy.json", json)
    return os.isfile(pkginfo.install_dir() .. "/policy.json")
end

function luban.boot(json)
    os.mkdir(pkginfo.install_dir())
    write("share/luban/boot.json", json)
    return true
end

return luban
