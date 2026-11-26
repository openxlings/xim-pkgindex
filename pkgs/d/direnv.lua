-- direnv - unclutter your .profile (direnv/direnv).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/direnv` and marks executable.
--
-- Verified against direnv/direnv release v2.38.2 (SHA-256 matched GitHub
-- release digests and downloaded bytes):
--   linux/x86_64    direnv.linux-amd64   (ELF64 static, readelf -d: no dynamic section)
--   linux/aarch64   direnv.linux-arm64   (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   direnv.darwin-amd64  (Mach-O 64-bit x86_64)
--   macosx/aarch64  direnv.darwin-arm64  (Mach-O 64-bit arm64)

package = {
    spec = "2",

    name = "direnv",
    description = "Unclutter your .profile: an extension for your shell that loads and unloads environment variables depending on the current directory",
    homepage = "https://direnv.net",
    maintainers = {"https://github.com/direnv/direnv/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/direnv/direnv",
    docs = "https://direnv.net/docs/installation.html",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "environment", "devtools", "tools"},
    keywords = {"direnv", "env", "dotenv", "shell", "environment", "cli"},

    programs = {"direnv"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/direnv/direnv/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/direnv/direnv/releases/download/${tag}/direnv.linux-amd64",
                            aarch64 = "https://github.com/direnv/direnv/releases/download/${tag}/direnv.linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/direnv/direnv/releases/download/${tag}/direnv.darwin-amd64",
                            aarch64 = "https://github.com/direnv/direnv/releases/download/${tag}/direnv.darwin-arm64",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/direnv/direnv/releases/download/v${version}/direnv.linux-${arch_alias}",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "148820a187930d36ca6a204504e5cdb30d8396cd1a97e64c3b3f10d793c11247",
                    aarch64 = "ec2a32dbe2f19dd085bd9315a1b4ea88b55ec288aa7eabe8723490baf466cb23",
                },
            },
        },
        macosx = {
            source = "https://github.com/direnv/direnv/releases/download/v${version}/direnv.darwin-${arch_alias}",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "91ad9ce96e156065ba2c751a7392ee748fa8e49b063e14d7203df6e957c212f9",
                    aarch64 = "30443c413e74614a53deb90234e9c97661b1041a0f4aca601ceb482a578ae8b6",
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
    return os.isfile(pkginfo.install_dir() .. "/direnv")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local target = dir .. "/direnv"

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    system.exec(string.format([[chmod +x "%s"]], target))
    if not os.isfile(target) then
        error("direnv: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("direnv", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("direnv")
    return true
end
