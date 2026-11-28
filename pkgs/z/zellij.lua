-- zellij -- a terminal workspace with batteries included (zellij-org/zellij).
--
-- Verified against official upstream release `zellij-org/zellij` v0.46.1:
--   * linux/x86_64    : zellij-x86_64-unknown-linux-musl.tar.gz
--                       `static-pie linked` musl ELF with zero DT_NEEDED entries
--                       (`ldd` reports `statically linked`).
--   * linux/aarch64   : zellij-aarch64-unknown-linux-musl.tar.gz
--                       `statically linked` musl ELF with no `.dynamic` section.
--   * macosx/x86_64   : zellij-x86_64-apple-darwin.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : zellij-aarch64-apple-darwin.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : zellij-x86_64-pc-windows-msvc.zip
--                       PE32+ executables (`zellij.exe` console + `zellij-terminal.exe` GUI)
--                       linked with static CRT (only Windows OS DLLs; no `VCRUNTIME140.dll`).
--   * windows/aarch64 : omitted — upstream v0.46.1 publishes no Windows ARM64 asset.
--
-- Archive layout: every upstream archive is flat at top level (`zellij` on POSIX;
-- `zellij.exe` + `zellij-terminal.exe` on Windows). `install()` unpacks directly
-- into `pkginfo.install_dir()` so shared runtime dirs never leak stray files.

package = {
    spec = "2",

    name = "zellij",
    description = "A terminal workspace with batteries included",
    homepage = "https://zellij.dev",
    authors = {"Aram Drevekenin", "Zellij Contributors"},
    maintainers = {"Zellij Contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/zellij-org/zellij",
    docs = "https://zellij.dev/documentation/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "terminal", "multiplexer", "tools"},
    keywords = {"zellij", "terminal", "multiplexer", "workspace", "tmux", "rust"},

    -- Keep `programs` limited to CLI `zellij` so Windows CI `/?` probing does
    -- not trigger the GUI `zellij-terminal.exe`.
    programs = {"zellij"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/zellij-org/zellij/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.46.1" },
            ["0.46.1"] = {
                sha256 = {
                    x86_64 = "1633211357c236053b51d1ae6415c23f7ff71aaae8e087315e499ceca1b17fa4",
                    aarch64 = "5371af1eae34a22da0fdc0a2d4c4bff648e3e75345adb341f14d93d678487c5c",
                },
            },
        },
        macosx = {
            source = "https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.46.1" },
            ["0.46.1"] = {
                sha256 = {
                    x86_64 = "39230d4f8306643c6051e76884bb5b1f038e0d41291862da62c9b1830c9a1504",
                    aarch64 = "97ace8e179b98576debd963870424cf208e1ef4fc9bd6180e3c73ff1d798087d",
                },
            },
        },
        windows = {
            source = "https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.46.1" },
            ["0.46.1"] = {
                sha256 = {
                    x86_64 = "a2fe1b52ba8cd08d75a3a7ee8b9ecf66d8a8bbaf65ed6096a506f65a69a2c77b",
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

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

function installed()
    if is_windows() then
        return payload.present({ "zellij.exe", "zellij-terminal.exe" })
    end
    return payload.present({ "zellij" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local is_win = is_windows()

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
        payload.require({ "zellij.exe", "zellij-terminal.exe" })
    else
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/zellij" })
        payload.require({ "zellij" })
    end

    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("zellij", { bindir = dir })
    if is_windows() and os.isfile(dir .. "/zellij-terminal.exe") then
        xvm.add("zellij-terminal", {
            bindir = dir,
            binding = "zellij@" .. pkginfo.version(),
        })
    end
    return true
end

function uninstall()
    if is_windows() then
        xvm.remove("zellij-terminal")
    end
    xvm.remove("zellij")
    return true
end
