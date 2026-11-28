-- Official YS-L/csvlens v0.15.1 assets, verified against GitHub digests and
-- upstream .sha256 sidecars. POSIX archives have a target-named root; zips
-- are flat. No fonts, shell configuration, or desktop integration is installed.
-- Linux x86_64 uses the static-pie musl build (no PT_INTERP/DT_NEEDED).
-- No aarch64 musl asset exists: its GNU ELF needs only glibc libraries
-- (libc, libm, libpthread, libdl; maximum GLIBC_2.30), supplied by xim:glibc.
-- Linux dependencies are platform-wide, so glibc is also resolved on x86_64.
-- macOS imports only Apple system libraries/frameworks (10.12 x86_64 / 11 arm64).
-- Both Windows binaries import only OS DLLs, not the Visual C++ runtime.
package = {
    spec = "2",
    name = "csvlens",
    description = "Command-line CSV viewer and interactive selector",
    homepage = "https://github.com/YS-L/csvlens",
    authors = {"YS-L"},
    maintainers = {"YS-L"},
    licenses = {"MIT"},
    repo = "https://github.com/YS-L/csvlens",
    docs = "https://github.com/YS-L/csvlens#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "cli", "tui"},
    keywords = {"csv", "viewer", "selector", "terminal", "rust"},
    programs = {"csvlens"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/YS-L/csvlens/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-x86_64-unknown-linux-musl.tar.xz",
                        aarch64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-aarch64-unknown-linux-gnu.tar.xz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-x86_64-apple-darwin.tar.xz",
                        aarch64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-aarch64-apple-darwin.tar.xz",
                    },
                    windows = {
                        x86_64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-x86_64-pc-windows-msvc.zip",
                        aarch64 = "https://github.com/YS-L/csvlens/releases/download/${tag}/csvlens-aarch64-pc-windows-msvc.zip",
                    },
                } },
            },
        },
    },
    xpm = {
        linux = {
            deps = { runtime = {"xim:glibc@>=2.39"} },
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = {
                x86_64 = {
                    url = "https://github.com/YS-L/csvlens/releases/download/v0.15.1/csvlens-x86_64-unknown-linux-musl.tar.xz",
                    sha256 = "ab086b420e453618fd1544eb4e09cc98279e8570b739725592feb241cd1bef4b",
                },
                aarch64 = {
                    url = "https://github.com/YS-L/csvlens/releases/download/v0.15.1/csvlens-aarch64-unknown-linux-gnu.tar.xz",
                    sha256 = "7671466036ebc22b1b9b958890a638fd21a06452137fb9ca1321448e5afea7ad",
                },
            },
        },
        macosx = {
            source = "https://github.com/YS-L/csvlens/releases/download/v${version}/csvlens-${arch}-apple-darwin.tar.xz",
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = { sha256 = {
                x86_64 = "26374c1d11fd628475e26d7ecbc8e6f4c4bbd76b15f48f31dd8609fdbbdd0137",
                aarch64 = "d227c0acee1ac49956eacf12f301e7ce2e20ab36aa863d4c44b8bca93ec8e7b3",
            } },
        },
        windows = {
            source = "https://github.com/YS-L/csvlens/releases/download/v${version}/csvlens-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = { sha256 = {
                x86_64 = "2b7cf7818288b98571382f0b65b8d03139ab2a1d71d2505ecdeb06a33186bf7d",
                aarch64 = "4ab4c02d025ada4d23a9818b9a76b521832e45b7412ef04f88dd20fea191d21a",
            } },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    local windows = os.getenv("OS") == "Windows_NT"
        or tostring(pkginfo.install_file() or ""):match("%.zip$") ~= nil
    return {windows and "csvlens.exe" or "csvlens", "LICENSE", "README.md", "CHANGELOG.md"}
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local stem = (archive:match("([^/]+)$") or ""):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
    payload.unpack{ extracted = stem }
    payload.require(required_files())
    return true
end

function config()
    xvm.add("csvlens", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("csvlens")
    return true
end
