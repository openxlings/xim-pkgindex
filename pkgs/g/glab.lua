-- GLab - GitLab's official command-line tool (gitlab.com/gitlab-org/cli).
--
-- Verified 2026-11-26 against GitLab release v1.133.0 and upstream
-- `checksums.txt`: every SHA256 below matched both the upstream checksums
-- file and the downloaded release archive bytes:
--   linux/x86_64    glab_1.133.0_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   glab_1.133.0_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   glab_1.133.0_darwin_amd64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  glab_1.133.0_darwin_arm64.tar.gz   (Mach-O 64-bit arm64)
--   windows/x86_64  glab_1.133.0_windows_amd64.zip     (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 glab_1.133.0_windows_arm64.zip     (PE32+ ARM64, imports kernel32.dll only)
--
-- All six archives are flat at root (`bin/glab` / `bin/glab.exe`,
-- `CHANGELOG.md`, `LICENSE`, `README.md` with no top-level wrapper
-- directory). `install()` extracts directly from `pkginfo.install_file()` into
-- a clean `install_dir()` so shared `runtimedir` contents from other flat
-- archives cannot leak into glab's payload.
--
-- Manual maintenance (no extensions.autoupdate):
--   Upstream releases are hosted on `gitlab.com/gitlab-org/cli` (not GitHub
--   Releases or a Sparkle XML appcast, which `xpkgindex-update` supports).
--   `ci = { mirror = true }` mirrors the declared GLOBAL archives to xlings-res.

package = {
    spec = "2",

    name = "glab",
    description = "GLab - A GitLab CLI tool bringing GitLab to your command line",
    homepage = "https://gitlab.com/gitlab-org/cli",
    authors = {"GitLab Inc."},
    maintainers = {"https://gitlab.com/gitlab-org/cli"},
    licenses = {"MIT"},
    repo = "https://gitlab.com/gitlab-org/cli",
    docs = "https://gitlab.com/gitlab-org/cli",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "git", "gitlab", "tools"},
    keywords = {"gitlab", "glab", "git", "merge-request", "cli"},

    programs = {"glab"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.133.0" },
            ["1.133.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b17f858b8d700f1607f8ec02fe092a455da6a8dd18dac3eb6ccb09db1befd4bf",
                    aarch64 = "a529fd254824b0f3f8d2350080c9b46633b67ff3e2b11455836d7a680c498b09",
                },
            },
        },
        macosx = {
            source = "https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.133.0" },
            ["1.133.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "62965e8361ce8ad52a5d6079f8ff155f9e3bc8bc4fb74e4c8e9c75d67043d803",
                    aarch64 = "d81ed2620b0d1374e2e0a8bfd90a3ef8945d177667d065a0945b301a1eada3e2",
                },
            },
        },
        windows = {
            source = "https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.133.0" },
            ["1.133.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0e8788d3d2f19e54745dae03a254d2b6726ecc033a6977e3b04e895ce8a48a0a",
                    aarch64 = "1fa6ce0f60c4188a12c32e81933fba07263121829d295d07778f6b7aea1cd042",
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
    return { exe, "CHANGELOG.md", "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("bin/glab"))
        or payload.present(required_files("bin/glab.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("glab: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil

    if is_win then
        payload.unpack{}
    else
        if not os.isfile(archive) then
            error("glab: archive not found: " .. archive)
        end
        os.tryrm(dir)
        fs.mkdir_p(dir)
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/bin/glab") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/bin/glab"))
        end
    end

    payload.require(required_files(is_win and "bin/glab.exe" or "bin/glab"))
    return true
end

function config()
    xvm.add("glab", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("glab")
    return true
end
