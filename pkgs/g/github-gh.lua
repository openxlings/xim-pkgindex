package = {
    spec = "1",

    name = "github-gh",
    description = "GitHub's official command line tool",

    homepage = "https://cli.github.com",
    maintainers = {"GitHub"},
    licenses = {"MIT"},
    repo = "https://github.com/cli/cli",
    docs = "https://cli.github.com/manual",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "github", "cli", "tools"},
    keywords = {"github", "gh", "cli", "git", "pull-request", "issue"},

    programs = {"gh", "github-gh"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/cli/cli/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/cli/cli/releases/download/v${version}/gh_${version}_linux_amd64.tar.gz",
                        macosx = "https://github.com/cli/cli/releases/download/v${version}/gh_${version}_macOS_amd64.zip",
                        windows = "https://github.com/cli/cli/releases/download/v${version}/gh_${version}_windows_amd64.zip",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {

            ["latest"] = { ref = "2.92.0" },
            ["2.92.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.92.0/gh_2.92.0_linux_amd64.tar.gz",
                sha256 = "b57848131bdf0c229cd35e1f2a51aa718199858b2e728410b37e89a428943ec4",
            },
            ["2.91.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.91.0/gh_2.91.0_linux_amd64.tar.gz",
                sha256 = "304a0d2460f4a8847d2f192bad4e2a32cd9420d28716e7ae32198181b65b5f9c",
            },
            ["2.86.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.86.0/gh_2.86.0_linux_amd64.tar.gz",
                sha256 = nil,
            },
            -- ["2.86.0"] = "XLINGS_RES",
        },
        macosx = {

            ["latest"] = { ref = "2.92.0" },
            ["2.92.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.92.0/gh_2.92.0_macOS_amd64.zip",
                sha256 = "ae9bb327ab0d91071bdada79f8f14034a2a0f19b0e001835a782eafa519d2af0",
            },
            ["2.91.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.91.0/gh_2.91.0_macOS_amd64.zip",
                sha256 = "8806784f93603fe6d3f95c3583a08df38f175df9ebc123dc8b15f919329980e2",
            },
            ["2.86.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.86.0/gh_2.86.0_macOS_amd64.zip",
                sha256 = nil,
            },
            -- ["2.86.0"] = "XLINGS_RES",
        },
        windows = {

            ["latest"] = { ref = "2.92.0" },
            ["2.92.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.92.0/gh_2.92.0_windows_amd64.zip",
                sha256 = "b6a8df3c8c6b9c80f290906387673bc4d272840f3789c5650e0e4e6e75522785",
            },
            ["2.91.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.91.0/gh_2.91.0_windows_amd64.zip",
                sha256 = "ced3e6f4bb5a9865056b594b7ad0cf42137dc92c494346f1ca705b5dbf14c88e",
            },
            ["2.86.0"] = {
                url = "https://github.com/cli/cli/releases/download/v2.86.0/gh_2.86.0_windows_amd64.zip",
                sha256 = nil,
            },
            -- ["2.86.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function installed()
    return os.iorun("gh --version")
end

function install()
    os.tryrm(pkginfo.install_dir())

    local gh_dir = string.format("gh_%s_linux_amd64", pkginfo.version())

    if os.host() == "macosx" then
        gh_dir = string.format("gh_%s_macOS_amd64", pkginfo.version())
    elseif os.host() == "windows" then
        gh_dir = string.format("gh_%s_windows_amd64", pkginfo.version())
    end

    os.mv(gh_dir, pkginfo.install_dir())
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add("gh", { bindir = bindir })
    xvm.add("github-gh", { bindir = bindir, alias = "gh" })
    return true
end

function uninstall()
    xvm.remove("gh")
    xvm.remove("github-gh")
    return true
end
