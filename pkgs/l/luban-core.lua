-- Luban Core: daily command-line development -- luban-tiny plus GNU tools,
-- a C/C++ toolchain, mcpp, git, editors and shells (Luban design §6).
--
--   luban new dev                       # core is luban's default edition
--   luban new dev core                  # (xlings subos new dev --from subos:luban-core)
--
-- A published version's output never changes (tests/fixtures/luban-published.json).
-- 2026.10.10.1 and later are from luban-tiny's date versions (no kernel in
-- the root; see luban-tiny).
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

import("xim.pkgindex.luban")

-- Each version's manifest and shells, as published.
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

local versions = {}
for v, e in pairs(editions) do
    versions[v] = { manifest = e.manifest, files = { { "usr/share/factory/etc/shells", e.shells } } }
end

function install()
    return luban.edition({ id = "core", variant = "Core", versions = versions })
end
