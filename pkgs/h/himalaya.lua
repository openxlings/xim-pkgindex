-- Himalaya v3.0.0: official flat archives, verified against GitHub asset digests.
-- Linux x86_64 is static PIE; aarch64 is static ELF (neither has DT_NEEDED).
-- Windows x86_64 imports only Windows system DLLs, including the system msvcrt;
-- it has no separately distributed MSVC runtime dependency.
-- The tagged Cargo.toml offers MIT OR Apache-2.0; both license files exist.
package = {
    spec = "2",
    name = "himalaya",
    description = "CLI to manage emails with local and remote backends",
    homepage = "https://pimalaya.org",
    authors = {"Clément DOUIN (soywod)"},
    maintainers = {"pimalaya"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/pimalaya/himalaya",
    docs = "https://github.com/pimalaya/himalaya#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"email", "cli", "tools"},
    keywords = {"himalaya", "email", "maildir", "imap", "rust"},
    programs = {"himalaya"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/pimalaya/himalaya/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/pimalaya/himalaya/releases/download/${tag}/himalaya.x86_64-linux.tgz",
                        aarch64 = "https://github.com/pimalaya/himalaya/releases/download/${tag}/himalaya.aarch64-linux.tgz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/pimalaya/himalaya/releases/download/${tag}/himalaya.x86_64-darwin.tgz",
                        aarch64 = "https://github.com/pimalaya/himalaya/releases/download/${tag}/himalaya.aarch64-darwin.tgz",
                    },
                    windows = {
                        x86_64 = "https://github.com/pimalaya/himalaya/releases/download/${tag}/himalaya.x86_64-windows.zip",
                    },
                } },
            },
        },
    },
    xpm = {
        linux = {
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                x86_64 = {
                    url = "https://github.com/pimalaya/himalaya/releases/download/v3.0.0/himalaya.x86_64-linux.tgz",
                    sha256 = "508514408465f03578b36d2c57e7ad5bbcfd023193931d7524a3a36664a2128b",
                },
                aarch64 = {
                    url = "https://github.com/pimalaya/himalaya/releases/download/v3.0.0/himalaya.aarch64-linux.tgz",
                    sha256 = "2045bb610f8c6829866a5f89f5e0e91606c3612c66533ff93c7eebbf36c1815f",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                x86_64 = {
                    url = "https://github.com/pimalaya/himalaya/releases/download/v3.0.0/himalaya.x86_64-darwin.tgz",
                    sha256 = "1e25542b573d23072b03cf24869ecf44daad33ed5813f8fd4d6f8ca905e3c882",
                },
                aarch64 = {
                    url = "https://github.com/pimalaya/himalaya/releases/download/v3.0.0/himalaya.aarch64-darwin.tgz",
                    sha256 = "9668e824c7d518ce0db4f01a10aa2f6a8d6c631b03a4ad20c4aba58f19d85ccb",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                x86_64 = {
                    url = "https://github.com/pimalaya/himalaya/releases/download/v3.0.0/himalaya.x86_64-windows.zip",
                    sha256 = "c4db8f443a583c04bca2c9eb03f4635a45e42c66bd34543c6f4cbae6e545f2b3",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files()
    local windows = os.getenv("OS") == "Windows_NT"
        or tostring(pkginfo.install_file() or ""):match("%.zip$") ~= nil
    return { windows and "himalaya.exe" or "himalaya", "share/doc/himalaya/config.sample.toml" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" or not os.isfile(archive) then
        error("himalaya: missing release archive: " .. archive)
    end
    local dir = pkginfo.install_dir()
    if archive:match("%.zip$") then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        -- Archives have no enclosing directory. Extract this archive, not the
        -- shared download directory, retaining the bundled manual and examples.
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/himalaya" })
    end
    payload.require(required_files())
    return true
end

function config()
    -- Registration only: never run the account wizard or create user config.
    xvm.add("himalaya", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("himalaya")
    return true
end
