-- watchexec: executes commands in response to file modifications.
--
-- Official prebuilt archives verified against watchexec/watchexec release v2.8.0
-- (SHA256SUMS and per-asset `.sha256` sidecar files):
--   * linux/x86_64:  static-pie musl ELF (`readelf -d`: no DT_NEEDED / PT_INTERP;
--                    `ldd`: "statically linked")
--   * linux/aarch64: statically linked musl ELF (`readelf -d`: no dynamic section /
--                    PT_INTERP; `ldd`: "not a dynamic executable")
--     -> No glibc or gcc-runtime dependency on Linux.
--   * macosx:        x86_64-apple-darwin and aarch64-apple-darwin `.tar.xz`
--   * windows:       x86_64-pc-windows-msvc `.zip`; `watchexec.exe` imports
--                    `VCRUNTIME140.dll`, so `xim:vcruntime` DLLs are copied
--                    app-local beside `watchexec.exe`. Windows ARM64
--                    (`watchexec-2.8.0-aarch64-pc-windows-msvc.zip`) also imports
--                    `VCRUNTIME140.dll` and waits for `xim:vcruntime` ARM64 DLL
--                    support.
--
-- Upstream archives extract into `watchexec-<ver>-<triple>/` with `watchexec`
-- (or `watchexec.exe`), `LICENSE`, `README.md`, `watchexec.1`, `watchexec.1.md`,
-- `logo.svg`, and `completions/`.

package = {
    spec = "2",

    name = "watchexec",
    description = "Executes commands in response to file modifications",
    homepage = "https://watchexec.github.io",
    authors = {"Félix Saparelli"},
    maintainers = {"https://github.com/watchexec/watchexec/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/watchexec/watchexec",
    docs = "https://watchexec.github.io/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "filesystem", "watcher", "tools"},
    keywords = {"watchexec", "watch", "file-watcher", "cli", "automation", "rust"},

    programs = {"watchexec"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/watchexec/watchexec/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-x86_64-unknown-linux-musl.tar.xz",
                            aarch64 = "https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-aarch64-unknown-linux-musl.tar.xz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-x86_64-apple-darwin.tar.xz",
                            aarch64 = "https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-aarch64-apple-darwin.tar.xz",
                        },
                        windows = {
                            x86_64 = "https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/watchexec/watchexec/releases/download/v${version}/watchexec-${version}-${arch}-unknown-linux-musl.tar.xz",
            ["latest"] = { ref = "2.8.0" },
            ["2.8.0"] = {
                sha256 = {
                    x86_64 = "35ea667cbe4bc96c23ba2a1f46c94c46bc385b67165e3bf621c0e7e4959aa99b",
                    aarch64 = "3961878b21e3c1729279322f4007dd5bbf0032110fbcb5e7b983946a9ceb3bf6",
                },
            },
        },
        macosx = {
            source = "https://github.com/watchexec/watchexec/releases/download/v${version}/watchexec-${version}-${arch}-apple-darwin.tar.xz",
            ["latest"] = { ref = "2.8.0" },
            ["2.8.0"] = {
                sha256 = {
                    x86_64 = "b7f694ad19c1cf168388f3295a5e825425f7dac5cd27cffd2d89a51ed4ab0f22",
                    aarch64 = "8da8bdbfb8568138616a082c05a87224e08d5cb2994feb956426291cf0c6fe10",
                },
            },
        },
        windows = {
            source = "https://github.com/watchexec/watchexec/releases/download/v${version}/watchexec-${version}-${arch}-pc-windows-msvc.zip",
            deps = {
                runtime = { "xim:vcruntime" },
            },
            -- Windows ARM64 waits for `xim:vcruntime` ARM64 runtime DLL support.
            ["latest"] = { ref = "2.8.0" },
            ["2.8.0"] = {
                sha256 = {
                    x86_64 = "0c872fc18c8e801f21614c6daf2504a5826d5c705bb67f7a583d879f5410d9ea",
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

function installed()
    return payload.present({ "watchexec" }) or payload.present({ "watchexec.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    if not is_win and normalized:match("%.tar%.xz$") and not os.isdir(parent .. "/" .. stem) and os.isfile(archive) then
        system.exec(string.format('tar -xJf "%s" -C "%s"', archive, parent))
    end

    payload.unpack{ extracted = stem, strip = 1 }

    if not is_win and os.isfile(dir .. "/watchexec") then
        system.exec(string.format('chmod +x "%s"', dir .. "/watchexec"))
    end

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "watchexec: xim:vcruntime payload directory is missing")
        local dlls = fs.files(crt .. "/bin") or {}
        if #dlls == 0 then
            error("watchexec: xim:vcruntime/bin contains no DLLs at " .. crt)
        end
        for _, dll in ipairs(dlls) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "watchexec.exe" or "watchexec" })
    return true
end

function config()
    xvm.add("watchexec", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("watchexec")
    return true
end
