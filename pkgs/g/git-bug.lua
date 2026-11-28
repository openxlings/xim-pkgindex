-- Upstream publishes six native binaries, but xim:git has no macOS resource
-- and only an x86_64 Windows resource. Do not fall back to the host's Git.
package = {
    spec = "2",
    name = "git-bug",
    description = "Distributed, offline-first bug tracker embedded in Git repositories",
    homepage = "https://github.com/git-bug/git-bug",
    repo = "https://github.com/git-bug/git-bug",
    docs = "https://github.com/git-bug/git-bug/tree/master/doc",
    maintainers = {"git-bug"},
    licenses = {"GPL-3.0-only"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "tools"},
    keywords = {"git-bug", "issues", "offline", "distributed"},
    programs = {"git-bug"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/git-bug/git-bug/releases",
            resources = { GLOBAL = { required = true, url = {
                linux = {
                    x86_64 = "https://github.com/git-bug/git-bug/releases/download/${tag}/git-bug_linux_amd64",
                    aarch64 = "https://github.com/git-bug/git-bug/releases/download/${tag}/git-bug_linux_arm64",
                },
                windows = {
                    x86_64 = "https://github.com/git-bug/git-bug/releases/download/${tag}/git-bug_windows_amd64.exe",
                },
            } } },
        },
    },
    xpm = {
        linux = {
            deps = { runtime = {"xim:git"} },
            source = "https://github.com/git-bug/git-bug/releases/download/v${version}/git-bug_linux_${arch_alias}",
            ["latest"] = { ref = "0.12.0" },
            ["0.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ff243821d70445df0bbbcd77d99ef65108fc3d632659a95e79c640ac0db57994",
                    aarch64 = "5a238294ff3c77d6a7592bab4f8748db5673fdcfd23c1e83d80b5820337b4f92",
                },
            },
        },
        windows = {
            deps = { runtime = {"xim:git"} },
            source = "https://github.com/git-bug/git-bug/releases/download/v${version}/git-bug_windows_${arch_alias}.exe",
            ["latest"] = { ref = "0.12.0" },
            ["0.12.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "1b891903991954570f04dcc898b38bde949905c2923845f0c18bb71cd967ef7b",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/git-bug") or os.isfile(dir .. "/git-bug.exe")
end

function install()
    local file = pkginfo.install_file()
    local windows = file:match("%.exe$") ~= nil
    local dir = pkginfo.install_dir()
    local target = dir .. (windows and "/git-bug.exe" or "/git-bug")
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(file, target)
    if not windows then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("git-bug: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("git-bug", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("git-bug")
    return true
end
