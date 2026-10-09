-- Luban Core (xlings SubOS design part 2 §9): `from` subos:luban-tiny@0.1.0, so its root
-- is that edition's plus what this one declares; a package or a file both
-- carry is this one's. Nothing to download -- install() writes the template.
--
--   xlings subos new mybox --rootfs --from subos:luban-core
package = {
    spec = "2",
    name = "luban-core",
    revision = 1,
    namespace = "subos",
    description = "Luban Core: luban-tiny plus bash, fish, Vim, Neovim, Git, mcpp, Claude and a C/C++ toolchain",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain", "gcc"},

    xpm = {
        linux = {
            ["latest"] = { ref = "0.2.0" },
            ["0.1.0"] = {},
            ["0.2.0"] = {},
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

local manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@0.2.0",
  "packages": [
    "xim:bash@5.2.37",
    "xim:fish@4.8.1",
    "xim:vim@8.1.1045",
    "xim:nvim@0.12.5",
    "xim:git@2.53.0",
    "xim:mcpp@2026.10.5.3",
    "xim:claude@2.1.281",
    "xim:coreutils@9.5",
    "xim:gcc@16.1.0",
    "xim:binutils@2.42.1",
    "xim:make@4.3",
    "xim:openssl@3.1.5",
    "xim:xz@5.8.3",
    "xim:zlib@1.3.1"
  ],
  "workspace": {}
}
]]

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    local content = manifest
    if pkginfo.version() == "0.1.0" then
        content = content:gsub("luban%-tiny@0%.2%.0", "luban-tiny@0.1.0")
        for _, name in ipairs({"fish", "vim", "nvim", "git", "mcpp", "claude"}) do
            content = content:gsub('    "xim:' .. name .. '@[^"\n]+",\n', "")
        end
    end
    write(".xlings.json", content)
    write("usr/share/factory/etc/os-release", (([[
NAME="Luban"
ID=luban
VARIANT="Core"
VARIANT_ID=core
VERSION_ID=0.2.0
PRETTY_NAME="Luban Core 0.2.0"
HOME_URL="https://github.com/openxlings/xlings"
]]):gsub("0%.2%.0", pkginfo.version())))
    write("usr/share/factory/etc/shells", "/bin/sh\n/bin/bash\n/usr/bin/fish\n")
    log.info("luban-core template at %s", pkginfo.install_dir())
    return true
end
