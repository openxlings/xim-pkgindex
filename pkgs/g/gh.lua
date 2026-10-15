-- GitHub CLI: the upstream's own static builds (Go, no libc to bind).
-- A base tool of Luban Core and Desktop.
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = (type(is_arch) == "function" and is_arch("aarch64")) and "aarch64" or "x86_64"
end
local linux_arch = (recipe_arch == "aarch64" or recipe_arch == "arm64") and "arm64" or "amd64"
local linux_sha256 = {
    ["2.102.0"] = {
        amd64 = "bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386",
        arm64 = "7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484",
    },
}

package = {
    spec = "1",

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
        linux = {
            ["latest"] = { ref = "2.102.0" },
            ["2.102.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_linux_" .. linux_arch .. ".tar.gz",
                sha256 = linux_sha256["2.102.0"][linux_arch],
            },
        },
        macosx = {
            ["latest"] = { ref = "2.102.0" },
            ["2.102.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_macOS_arm64.zip",
                sha256 = "da922c20d1792e5b2cbf375593d7a658acf034c12c84e007e71c76ef959c337e",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The archive extracts into `gh_<version>_<os>_<arch>/` with bin/gh, its
-- man pages and the licence: kept as they are.
function install()
    os.tryrm(pkginfo.install_dir())
    local extracted = pkginfo.install_file():replace(".tar.gz", ""):replace(".zip", "")
    os.mv(extracted, pkginfo.install_dir())
    return os.isfile(path.join(pkginfo.install_dir(), "bin", "gh"))
end

function config()
    xvm.add("gh", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("gh")
    return true
end
