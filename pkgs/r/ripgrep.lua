package = {
    spec = "1",

    name = "ripgrep",
    description = "Fast, recursive grep that respects .gitignore",
    homepage = "https://github.com/BurntSushi/ripgrep",
    maintainers = {"Andrew Gallant"},
    licenses = {"MIT", "Unlicense"},
    repo = "https://github.com/BurntSushi/ripgrep",
    docs = "https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "search", "tools"},
    keywords = {"grep", "search", "ripgrep", "rg", "rust"},

    programs = {"rg"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/BurntSushi/ripgrep/releases/download/{version}/ripgrep-{version}-x86_64-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "1c9297be4a084eea7ecaedf93eb03d058d6faae29bbc57ecdaf5063921491599",
            },
        },
        macosx = {
            url_template = "https://github.com/BurntSushi/ripgrep/releases/download/{version}/ripgrep-{version}-aarch64-apple-darwin.tar.gz",
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz",
                sha256 = "378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715",
            },
        },
        windows = {
            url_template = "https://github.com/BurntSushi/ripgrep/releases/download/{version}/ripgrep-{version}-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-pc-windows-msvc.zip",
                sha256 = "124510b94b6baa3380d051fdf4650eaa80a302c876d611e9dba0b2e18d87493a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archive layouts:
--   linux/macOS .tar.gz → enclosing dir `ripgrep-<ver>-<triple>/` with `rg`
--   windows .zip        → enclosing dir `ripgrep-<ver>-<triple>/` with `rg.exe`
--
-- xlings auto-extracts the archive into the runtime download dir, so the
-- extracted folder lives next to install_file with the same name minus the
-- archive suffix.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local extracted = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")

    local exe = is_host("windows") and "rg.exe" or "rg"
    os.mv(path.join(extracted, exe), path.join(pkginfo.install_dir(), exe))
    os.tryrm(extracted)
    return true
end

function config()
    xvm.add("rg", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `rg` but the package name is `ripgrep`.
    -- Empty placeholder so install detection (`xvm info ripgrep`)
    -- finds an entry instead of treating the package as missing.
    xvm.add("ripgrep", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("rg")
    xvm.remove("ripgrep")
    return true
end
