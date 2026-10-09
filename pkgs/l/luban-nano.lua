-- Luban Nano: the Luban model itself (Luban design §A4) -- a root with
-- nothing in it but what every Luban root has: xlings (packages) and luban
-- (the system; stage-0 as luban-init), both static, no libc, no shell.
--
-- Everything above the kernel is a choice, and nano makes none: a libc, an
-- init, base tools, a shell are packages an edition `from` this one declares.
-- An edition of your own:
--
--   { "subos_kind": "rootfs", "from": "subos:luban-nano",
--     "abi": "x86_64-linux-gnu",
--     "packages": [ "xim:glibc@2.44.3", "xim:busybox@1.35.0" ],
--     "boot": { "init": "/sbin/init" } }
--
-- packed as an xpkg in your own index (`xlings subos pack`), it is a
-- distribution based on Luban: `luban new box your-index:your-os`.
package = {
    spec = "2",
    name = "luban-nano",
    namespace = "subos",
    description = "Luban Nano: xlings and luban only -- the base every Luban edition builds on",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "nano", "minimal", "embedded"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.10.1" },
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")

local function write(rel, content)
    local file = pkginfo.install_dir() .. "/" .. rel
    os.mkdir(assert(file:match("^(.*)/[^/]+$")))
    local f = io.open(file, "wb")
    if not f then error("cannot write " .. file) end
    assert(f:write(content))
    f:close()
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    -- No packages: xlings and luban are in every root (its projection).
    -- No libc: what they are needs none. No init: that is a choice.
    write(".xlings.json", [[
{
  "subos_kind": "rootfs",
  "abi": { "kernel": "linux", "libc": "none" },
  "packages": [],
  "boot": { "kernel": "xim:linux-kernel@6.8.0-71", "kernel_min": "5.10" },
  "workspace": {}
}
]])
    write("usr/share/factory/etc/os-release", string.format([[
NAME="Luban"
ID=luban
VARIANT="Nano"
VARIANT_ID=nano
VERSION_ID=%s
PRETTY_NAME="Luban Nano %s"
HOME_URL="https://github.com/openxlings/xlings"
]], pkginfo.version(), pkginfo.version()))
    log.info("luban-nano template at %s", pkginfo.install_dir())
    return true
end
