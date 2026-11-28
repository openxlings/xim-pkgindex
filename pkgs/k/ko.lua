-- ko - Build and deploy Go applications (ko-build/ko).
--
-- Verified 2026-11-26 against upstream GitHub release v0.19.1 and
-- `checksums.txt`: every SHA-256 below matched the upstream checksums file
-- and downloaded archive bytes:
--   linux/x86_64    ko_0.19.1_Linux_x86_64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   ko_0.19.1_Linux_arm64.tar.gz     (static Go ELF, no .dynamic section)
--   macosx/x86_64   ko_0.19.1_Darwin_x86_64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  ko_0.19.1_Darwin_arm64.tar.gz    (Mach-O 64-bit arm64)
--   windows/x86_64  ko_0.19.1_Windows_x86_64.tar.gz  (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 ko_0.19.1_Windows_arm64.tar.gz   (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes i386, mips64le, ppc64le, riscv64, and s390x archives,
-- which are outside `archs`. All six supported archives are flat `.tar.gz` at
-- root (`ko` / `ko.exe`, `LICENSE`, `README.md` with no top-level wrapper
-- directory). `install()` extracts directly from `pkginfo.install_file()` into
-- a clean `pkginfo.install_dir()` so shared `runtimedir` contents from other
-- flat archives cannot leak into this payload.

package = {
    spec = "2",

    name = "ko",
    description = "Build and deploy Go applications",
    homepage = "https://ko.build",
    maintainers = {"ko-build"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/ko-build/ko",
    docs = "https://ko.build",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"go", "containers", "kubernetes", "cli", "devops"},
    keywords = {"ko", "go", "containers", "oci", "kubernetes", "k8s", "cli"},

    programs = {"ko"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/ko-build/ko/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Windows_x86_64.tar.gz",
                            aarch64 = "https://github.com/ko-build/ko/releases/download/${tag}/ko_${version}_Windows_arm64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executables import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/ko-build/ko/releases/download/v${version}/ko_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.19.1" },
            ["0.19.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "635ac6ea3fd376c935fee597fbb29ab2c2449f49ef1655085fe3aa9c25fed7a5",
                    aarch64 = "4099b2d1170d3b8a70e049237462efc2dd14d5fa30e9d2e5e108fb4f778cdd3f",
                },
            },
        },
        macosx = {
            source = "https://github.com/ko-build/ko/releases/download/v${version}/ko_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.19.1" },
            ["0.19.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1b4ed52a5e506a55b085c7f106eb743ee756c776cc90fa232a539a47ad665310",
                    aarch64 = "a1338c4140c8c94e789733e21b161a3de177b467cd3c388b634fe1a869574509",
                },
            },
        },
        windows = {
            source = "https://github.com/ko-build/ko/releases/download/v${version}/ko_${version}_Windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.19.1" },
            ["0.19.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f70b0c9ea1874e81358a1886d478ebee9eb17d4f07e8dcaa779c4250a2aaea70",
                    aarch64 = "7fd21854bc3bdab2f71e4927cc8e39c60bdaf99992fd4442bfee0fe84025feed",
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
import("xim.pkgindex.winpath")

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("ko"))
        or payload.present(required_files("ko.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("ko: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_Windows_") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "ko.exe" or "ko"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            -- libs/payload.lua only dispatches .zip; Windows ships flat .tar.gz,
            -- so invoke Windows built-in bsdtar (System32\tar.exe) explicitly.
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            -- Extract flat .tar.gz directly into install_dir so files never mix
            -- with other flat archives in the shared runtimedir.
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
            system.exec(string.format('chmod +x "%s"', dir .. "/ko"))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        for _, f in ipairs(required_files(exe)) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/ko"))
        end
    else
        error("ko: archive not found at " .. archive)
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("ko", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("ko")
    return true
end
