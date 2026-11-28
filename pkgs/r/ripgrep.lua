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

    extensions = {
        autoupdate = {
            source = "https://github.com/BurntSushi/ripgrep/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-x86_64-unknown-linux-musl.tar.gz",
                        macosx = "https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-aarch64-apple-darwin.tar.gz",
                        windows = "https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-x86_64-pc-windows-msvc.zip",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {

            ["latest"] = { ref = "16.0.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "1c9297be4a084eea7ecaedf93eb03d058d6faae29bbc57ecdaf5063921491599",
            },
            ["15.2.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c",
            },
            ["16.0.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/16.0.0/ripgrep-16.0.0-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "54268ab4643c00a290a29b0086066d64b3f56236dd805ec64629a86f9bd29fd0",
            },
        },
        macosx = {

            ["latest"] = { ref = "16.0.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz",
                sha256 = "378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715",
            },
            ["15.2.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-aarch64-apple-darwin.tar.gz",
                sha256 = "3750b2e93f37e0c692657da574d7019a101c0084da05a790c83fd335bad973e4",
            },
            ["16.0.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/16.0.0/ripgrep-16.0.0-aarch64-apple-darwin.tar.gz",
                sha256 = "5a145656d5067144001bfce6648767fd3254599aa736f1ffdb7fb907760b8ca1",
            },
        },
        windows = {

            ["latest"] = { ref = "16.0.0" },
            ["15.1.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-pc-windows-msvc.zip",
                sha256 = "124510b94b6baa3380d051fdf4650eaa80a302c876d611e9dba0b2e18d87493a",
            },
            ["15.2.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-pc-windows-msvc.zip",
                sha256 = "71b2fef860abe467217a538ff31de02f5258807c0129f771846f87bd029aafc5",
            },
            ["16.0.0"] = {
                url = "https://github.com/BurntSushi/ripgrep/releases/download/16.0.0/ripgrep-16.0.0-x86_64-pc-windows-msvc.zip",
                sha256 = "f418ae83e63046a94a7b5f3a44bf3a169f66e689164856ecee02547131c73931",
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
    -- `group` is the only kind that both avoids a bogus shim under the
    -- package name and lets `xlings remove` find the package; removal of a
    -- group root needs xlings >= 2026.7.x, which is why CI pins a current
    -- client (older ones refuse the remove and leak the shims).
    xvm.add("ripgrep", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("rg")
    xvm.remove("ripgrep")
    return true
end
