-- Luban Core (xlings: 2026-10-18 Luban OS distribution design §6.1): daily command-line development -- tiny plus GNU tools, a C/C++ toolchain, mcpp, git and gh, editors and shells.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-core is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "core",
    namespace = "luban",
    description = "Luban Core: tiny plus bash, fish, vim, nvim, git, gh, mcpp and a C/C++ toolchain",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
        },
    },
}

import("xim.pkgindex.luban")

local versions = {
    ["2026.10.18.1"] = {
        files = luban.with({ { "usr/share/factory/etc/shells", "/bin/sh\n/bin/bash\n/usr/bin/fish\n" } },
                           luban.command_not_found(), luban.mcpp_config(), luban.checks("core", [[
{"checks": [
  {"id": "core-c++", "what": "g++ builds and runs a C++ program", "run": "d=$(mktemp -d) && printf '#include <vector>\\nint main() { std::vector<int> v{1}; return int(v.size()) - 1; }\\n' > $d/a.cpp && g++ -std=c++23 -o $d/a $d/a.cpp && $d/a; r=$?; rm -rf $d; exit $r", "timeout": 120},
  {"id": "core-tools", "what": "git, fish, nvim and mcpp start", "run": "git --version && fish --version && nvim --version && mcpp --version", "timeout": 60},
  {"id": "core-command-not-found", "what": "a command not found says what it may be", "run": "/usr/libexec/luban/command-not-found xlnigs 2>&1 | grep -q xlings", "timeout": 30}
]}
]])),
        manifest = {
            subos_kind = "rootfs",
            min_client = "2026.10.18.1",
            from = "luban:tiny@2026.10.18.1",
            replaces = "subos:luban-core",
            abi = { kernel = "linux", libc = "gnu" },
            packages = { "xim:bash@5.2.37", "xim:fish@4.8.1", "xim:vim@9.2.1172", "xim:nvim@0.12.5", "xim:git@2.53.0-1", "xim:gh@2.102.0",
                         "xim:mcpp@2026.10.16.3", "xim:ninja@1.12.1", "xim:coreutils@9.5", "xim:gcc@16.1.0", "xim:binutils@2.42.1",
                         "xim:make@4.3", "xim:openssl@3.1.5", "xim:xz@5.8.3", "xim:zlib@1.3.1" },
            luban = { settings = { enter = "console", login_shell = "/usr/bin/fish" } },
            workspace = {},
        },
    },
}

function install()
    return luban.edition({ id = "core", variant = "Core", versions = versions })
end
