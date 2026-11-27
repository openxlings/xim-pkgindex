-- GitHub CLI: the upstream's own static builds (Go, no libc to bind).
-- A base tool of Luban Core and Desktop.
package = {
    spec = "3",

    name = "gh",
    description = "GitHub's official command line tool",
    homepage = "https://cli.github.com",
    licenses = {"MIT"},
    repo = "https://github.com/cli/cli",
    docs = "https://cli.github.com/manual",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "git", "tools"},
    keywords = {"github", "gh", "git", "pull-request"},

    programs = {"gh"},
    xvm_enable = true,

    xpm = {
        -- Each archive holds `gh_<version>_<os>_<arch>/` with bin/gh, its man
        -- pages and the licence: that directory is dropped (strip).
        linux = {
            strip = 1,
            ["latest"] = { ref = "2.102.0" },
            ["2.102.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_linux_${arch_alias}.tar.gz",
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386",
                    aarch64 = "7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484",
                },
            },
        },
        macosx = {
            strip = 1,
            ["latest"] = { ref = "2.102.0" },
            ["2.102.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_macOS_arm64.zip",
                sha256 = { aarch64 = "da922c20d1792e5b2cbf375593d7a658acf034c12c84e007e71c76ef959c337e" },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.path")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    if not fs.is_file(path.join(pkginfo.install_dir(), "bin", "gh")) then
        error("gh: bin/gh is not in the archive")
    end
end

function config()
    xvm.add("gh", { bindir = path.join(pkginfo.install_dir(), "bin") })
end

function uninstall()
    xvm.remove("gh")
end
