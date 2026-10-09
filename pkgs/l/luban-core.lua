-- Luban Core: daily command-line development -- luban-tiny plus GNU tools,
-- a C/C++ toolchain, mcpp, git, editors and shells (Luban design §6).
--
--   luban new dev                       # core is luban's default edition
--   luban new dev core                  # (xlings subos new dev --from subos:luban-core)
--
-- A published version's manifest never changes. 2026.10.10.1 and later are
-- from luban-tiny's date versions (no kernel in the root; see luban-tiny).
-- An agent's tools are not here: they are luban-agent-workspace's.
package = {
    spec = "2",
    name = "luban-core",
    namespace = "subos",
    description = "Luban Core: luban-tiny plus bash, fish, vim, nvim, git, mcpp and a C/C++ toolchain",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.10.1" },
            ["0.1.0"] = {},
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

-- Each published version's manifest and shells, as published.
local editions = {
    ["0.1.0"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@0.1.0",
  "packages": [
    "xim:bash@5.2.37",
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
]],
        shells = "/bin/sh\n/bin/bash\n",
    },
    ["2026.10.10.1"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@2026.10.10.1",
  "abi": "x86_64-linux-gnu",
  "packages": [
    "xim:bash@5.2.37",
    "xim:fish@4.8.1",
    "xim:vim@8.1.1045",
    "xim:nvim@0.12.5",
    "xim:git@2.53.0",
    "xim:mcpp@2026.10.5.3",
    "xim:ninja@1.12.1",
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
]],
        shells = "/bin/sh\n/bin/bash\n/usr/bin/fish\n",
    },
}

function install()
    local edition = editions[pkginfo.version()]
    if not edition then error("luban-core: no manifest for " .. tostring(pkginfo.version())) end
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    write(".xlings.json", edition.manifest)
    write("usr/share/factory/etc/os-release", string.format([[
NAME="Luban"
ID=luban
VARIANT="Core"
VARIANT_ID=core
VERSION_ID=%s
PRETTY_NAME="Luban Core %s"
HOME_URL="https://github.com/openxlings/xlings"
]], pkginfo.version(), pkginfo.version()))
    write("usr/share/factory/etc/shells", edition.shells)
    log.info("luban-core template at %s", pkginfo.install_dir())
    return true
end
