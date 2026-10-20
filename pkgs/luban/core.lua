-- Luban Core (xlings: 2026-10-18 Luban OS distribution design §6.1): daily command-line development -- tiny plus GNU tools, a C/C++ toolchain, mcpp, git and gh, editors and shells.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-core is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
-- The machine's arch: the catalog loader binds os.arch; the runtime that runs
-- install() does not (nor is_arch), so there luban.arch() asks _RUNTIME and uname.
import("xim.pkgindex.luban")
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = luban.arch()
end
local aarch64 = recipe_arch == "aarch64" or recipe_arch == "arm64"

package = {
    spec = "2",
    name = "core",
    namespace = "luban",
    description = "Luban Core: tiny plus bash, fish, vim, nvim, git, gh, mcpp, cmake, xmake, yazi, procps and a C/C++ toolchain",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain"},

    -- What a Luban OS card shows of it (xlings design 2026-10-19 §20; xpkg
    -- spec "extensions"): a few of its programs; cmake and xmake where they
    -- are offered (x86_64).
    extensions = { luban = { highlights = aarch64 and { "gcc", "git", "nvim", "fish", "yazi" }
        or { "gcc", "cmake", "xmake", "git", "nvim", "yazi" } } },

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.20.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.19.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.20.1"] = { min_client = "2026.10.20.1" },
        },
    },
}


-- 2026.10.19.1's tools beyond 2026.10.18.1 (xlings design 2026-10-19 §20).
-- On aarch64 cmake and xmake are not offered yet: upstream ships no linux
-- aarch64 xmake, and cmake's GUI libraries (fontconfig, freetype, libxcb) are
-- x86_64 only in this index. procps-ng is above tiny's BusyBox: a system's
-- ps is procps-ng's (a layer above wins a program's name).
local tools_2026_10_19 = aarch64 and { "xim:yazi@26.5.6", "xim:procps-ng@4.0.5" }
    or { "xim:cmake@4.4.2", "xim:xmake@3.1.1", "xim:yazi@26.5.6", "xim:procps-ng@4.0.5" }
local base_2026_10_18 = { "xim:bash@5.2.37", "xim:fish@4.8.1", "xim:vim@9.2.1172", "xim:nvim@0.12.5", "xim:git@2.53.0-1",
                          "xim:gh@2.102.0", "xim:mcpp@2026.10.16.3", "xim:ninja@1.12.1", "xim:coreutils@9.5", "xim:gcc@16.1.0",
                          "xim:binutils@2.42.1", "xim:make@4.3", "xim:openssl@3.1.5", "xim:xz@5.8.3", "xim:zlib@1.3.1" }
local packages_2026_10_19 = {}
for _, p in ipairs(base_2026_10_18) do table.insert(packages_2026_10_19, p) end
for _, p in ipairs(tools_2026_10_19) do table.insert(packages_2026_10_19, p) end
local tool_check = "git --version && fish --version && nvim --version && mcpp --version && yazi --version"
    .. " && ps -C ps -o pid= >/dev/null"
    .. (aarch64 and "" or " && cmake --version && XMAKE_ROOT=y xmake --version")

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

versions["2026.10.19.1"] = {
    files = luban.with({ { "usr/share/factory/etc/shells", "/bin/sh\n/bin/bash\n/usr/bin/fish\n" } },
                       luban.command_not_found(), luban.mcpp_config(), luban.checks("core", [[
{"checks": [
  {"id": "core-c++", "what": "g++ builds and runs a C++ program", "run": "d=$(mktemp -d) && printf '#include <vector>\\nint main() { std::vector<int> v{1}; return int(v.size()) - 1; }\\n' > $d/a.cpp && g++ -std=c++23 -o $d/a $d/a.cpp && $d/a; r=$?; rm -rf $d; exit $r", "timeout": 120},
  {"id": "core-tools", "what": "git, fish, nvim, mcpp, yazi, procps (and cmake, xmake on x86_64) start; ps is procps's", "run": "]] .. tool_check .. [[", "timeout": 60},
  {"id": "core-command-not-found", "what": "a command not found says what it may be", "run": "/usr/libexec/luban/command-not-found xlnigs 2>&1 | grep -q xlings", "timeout": 30}
]}
]])),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.18.1",
        from = "luban:tiny@2026.10.18.1",
        replaces = "subos:luban-core",
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_19,
        luban = { settings = { enter = "console", login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.20.1 (xlings design 2026-10-20 §4.5): sudo -- a static one built by
-- the index's factory; the system's users are in wheel and sudo asks for
-- their password (the client writes /etc/sudoers.d/luban, and in a machine
-- makes it and sudo root's at boot: 2026.10.20.1).
local packages_2026_10_20 = {}
for _, p in ipairs(packages_2026_10_19) do table.insert(packages_2026_10_20, p) end
table.insert(packages_2026_10_20, "xim:sudo@1.9.17p2")

versions["2026.10.20.1"] = {
    files = luban.with({ { "usr/share/factory/etc/shells", "/bin/sh\n/bin/bash\n/usr/bin/fish\n" } },
                       luban.command_not_found(), luban.mcpp_config(), luban.checks("core", [[
{"checks": [
  {"id": "core-c++", "what": "g++ builds and runs a C++ program", "run": "d=$(mktemp -d) && printf '#include <vector>\\nint main() { std::vector<int> v{1}; return int(v.size()) - 1; }\\n' > $d/a.cpp && g++ -std=c++23 -o $d/a $d/a.cpp && $d/a; r=$?; rm -rf $d; exit $r", "timeout": 120},
  {"id": "core-tools", "what": "git, fish, nvim, mcpp, yazi, procps (and cmake, xmake on x86_64) start; ps is procps's", "run": "]] .. tool_check .. [[", "timeout": 60},
  {"id": "core-sudo", "what": "sudo is there and says its version", "run": "sudo -V >/dev/null", "timeout": 30},
  {"id": "core-command-not-found", "what": "a command not found says what it may be", "run": "/usr/libexec/luban/command-not-found xlnigs 2>&1 | grep -q xlings", "timeout": 30}
]}
]])),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:tiny@2026.10.18.1",
        replaces = "subos:luban-core",
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_20,
        luban = { settings = { enter = "console", login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

function install()
    return luban.edition({ id = "core", variant = "Core", versions = versions })
end
