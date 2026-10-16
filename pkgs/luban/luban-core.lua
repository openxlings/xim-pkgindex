-- Luban Core: daily command-line development -- luban-tiny plus GNU tools,
-- a C/C++ toolchain, mcpp, git and gh, editors and shells (Luban design §6).
--
--   luban new dev                       # core is luban's default edition
--   luban new dev core                  # (xlings subos new dev --from subos:luban-core)
--
-- A published version's output never changes (tests/fixtures/luban-published.json).
-- 2026.10.11.1 and later are from luban-tiny's date versions (no kernel in
-- the root; see luban-tiny).
-- An agent's tools are not here: they are luban-agent-workspace's.
package = {
    spec = "2",
    name = "luban-core",
    namespace = "subos",
    description = "Luban Core: luban-tiny plus bash, fish, vim, nvim, git, gh, mcpp and a C/C++ toolchain",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.16.1" },
            ["0.1.0"] = {},
            ["2026.10.11.1"] = {},
            ["2026.10.11.2"] = {},
            ["2026.10.15.1"] = {},
            ["2026.10.16.1"] = {},
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
    ["2026.10.11.1"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@2026.10.11.1",
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
    -- x86_64 and aarch64: every package below is published for both (vim and
    -- git are this index's own static builds now; gcc and binutils built on an
    -- arm runner as x86_64's were). An environment made from 2026.10.11.1
    -- moves here with `luban upgrade`.
    ["2026.10.11.2"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.11.1",
  "from": "subos:luban-tiny@2026.10.11.1",
  "abi": { "kernel": "linux", "libc": "gnu" },
  "packages": [
    "xim:bash@5.2.37",
    "xim:fish@4.8.1",
    "xim:vim@9.2.1172",
    "xim:nvim@0.12.5",
    "xim:git@2.53.0-1",
    "xim:mcpp@2026.10.11.1",
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
    -- gh, GitHub's command line, is a base tool beside git.
    ["2026.10.15.1"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.11.1",
  "from": "subos:luban-tiny@2026.10.11.1",
  "abi": { "kernel": "linux", "libc": "gnu" },
  "packages": [
    "xim:bash@5.2.37",
    "xim:fish@4.8.1",
    "xim:vim@9.2.1172",
    "xim:nvim@0.12.5",
    "xim:git@2.53.0-1",
    "xim:gh@2.102.0",
    "xim:mcpp@2026.10.11.1",
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
    -- On luban-tiny 2026.10.16.1 (terminfo): a command not found says what
    -- it may be, mcpp borrows the system's gcc (/etc/mcpp/config.toml), and
    -- the system checks itself.
    ["2026.10.16.1"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.16.1",
  "from": "subos:luban-tiny@2026.10.16.1",
  "abi": { "kernel": "linux", "libc": "gnu" },
  "packages": [
    "xim:bash@5.2.37",
    "xim:fish@4.8.1",
    "xim:vim@9.2.1172",
    "xim:nvim@0.12.5",
    "xim:git@2.53.0-1",
    "xim:gh@2.102.0",
    "xim:mcpp@2026.10.11.1",
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
        more = luban.with(luban.command_not_found(), luban.mcpp_config(), luban.checks("core", [[
{"checks": [
  {"id": "core-c++", "what": "g++ builds and runs a C++ program", "run": "d=$(mktemp -d) && printf '#include <vector>\\nint main() { std::vector<int> v{1}; return int(v.size()) - 1; }\\n' > $d/a.cpp && g++ -std=c++23 -o $d/a $d/a.cpp && $d/a; r=$?; rm -rf $d; exit $r", "timeout": 120},
  {"id": "core-tools", "what": "git, fish, nvim and mcpp start", "run": "git --version && fish --version && nvim --version && mcpp --version", "timeout": 60},
  {"id": "core-command-not-found", "what": "a command not found says what it may be", "run": "/usr/libexec/luban/command-not-found xlnigs 2>&1 | grep -q xlings", "timeout": 30}
]}
]])),
    },
}

-- 0.1.0 and 2026.10.11.1 name x86_64-only packages: an aarch64 reader
-- refuses them rather than make an environment half.
local recipe_arch = (os.arch and os.arch())
if recipe_arch == "aarch64" or recipe_arch == "arm64" then
    package.xpm.linux["0.1.0"] = nil
    package.xpm.linux["2026.10.11.1"] = nil
    editions["0.1.0"] = nil
    editions["2026.10.11.1"] = nil
end

local versions = {}
for v, e in pairs(editions) do
    versions[v] = { manifest = e.manifest, files = luban.with({ { "usr/share/factory/etc/shells", e.shells } }, e.more or {}) }
end

function install()
    return luban.edition({ id = "core", variant = "Core", versions = versions })
end
