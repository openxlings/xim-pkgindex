-- Official versioned portable archives; installing never initializes/applies dotfiles.
-- Completions remain inert in the package directory; no user config is created.
-- Linux amd64 uses upstream's static musl build; arm64 has one portable build.
package = {
    spec = "2",
    name = "chezmoi",
    description = "Manage your dotfiles across multiple diverse machines, securely",
    homepage = "https://www.chezmoi.io",
    authors = {"Tom Payne and contributors"},
    maintainers = {"twpayne"},
    licenses = {"MIT"},
    repo = "https://github.com/twpayne/chezmoi",
    docs = "https://www.chezmoi.io/user-guide/command-overview/",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools"},
    keywords = {"chezmoi", "dotfiles", "configuration"},
    programs = {"chezmoi"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/twpayne/chezmoi/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_linux-musl_amd64.tar.gz",
                        aarch64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_linux_arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_darwin_amd64.tar.gz",
                        aarch64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_darwin_arm64.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_windows_amd64.zip",
                        aarch64 = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_windows_arm64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "2.74.2" },
            ["2.74.2"] = {
                x86_64 = {
                    url = "https://github.com/twpayne/chezmoi/releases/download/v2.74.2/chezmoi_2.74.2_linux-musl_amd64.tar.gz",
                    sha256 = "0570eea5af5dea146d872423a65bdf46f140087fbb01ed279dc0c219e1e1da49",
                },
                aarch64 = {
                    url = "https://github.com/twpayne/chezmoi/releases/download/v2.74.2/chezmoi_2.74.2_linux_arm64.tar.gz",
                    sha256 = "bb1521dd02aff3967d61937213110e79ddd6e181e0856cf51e80dba01fda245f",
                },
            },
        },
        macosx = {
            source = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.74.2" },
            ["2.74.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "26c75a1519bde46306a0d4232dcba3223c76683c0162b70438fc2775702dda05",
                    aarch64 = "fa14debabd557a9bb88a35c2950be6f5a8adf12e1c8cc26a9e0ee62fe0bdef2b",
                },
            },
        },
        windows = {
            source = "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.74.2" },
            ["2.74.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6b3a0480d0d31cc72a9ef676ae44bb6a5de1222c7bca11db8799a59e9df0e78a",
                    aarch64 = "ec489d6932265f21e3ce708dfbd875f1ccc3dbc7cecb7d16eecf8bac179d8c41",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files(exe)
    return {
        exe, "LICENSE", "README.md",
        "completions/chezmoi-completion.bash", "completions/chezmoi.fish",
        "completions/chezmoi.ps1", "completions/chezmoi.zsh",
    }
end

function installed()
    return payload.present(required_files("chezmoi"))
        or payload.present(required_files("chezmoi.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local dir = pkginfo.install_dir()
    local is_win = archive:match("%.zip$") ~= nil
    if is_win then
        payload.unpack{}
    else
        if archive == "" or not os.isfile(archive) then
            error("chezmoi: archive not found: " .. archive)
        end
        os.tryrm(dir)
        fs.mkdir_p(dir)
        -- The tarballs are flat, not wrapped in an enclosing directory.
        system.exec(string.format('tar -xzf "%s" -C "%s"', archive, dir))
    end
    payload.require(required_files(is_win and "chezmoi.exe" or "chezmoi"))
    return true
end

function config()
    xvm.add("chezmoi", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("chezmoi")
    return true
end
