-- GoReleaser - Release engineering, simplified (goreleaser/goreleaser).
--
-- Verified 2026-11-26 against upstream GitHub release v2.20.3 and
-- `checksums.txt`: every SHA256 below matched both the upstream checksums file
-- and the downloaded release archive bytes:
--   linux/x86_64    goreleaser_Linux_x86_64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   goreleaser_Linux_arm64.tar.gz     (static Go ELF, no .dynamic section)
--   macosx/x86_64   goreleaser_Darwin_x86_64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  goreleaser_Darwin_arm64.tar.gz    (Mach-O 64-bit arm64)
--   windows/x86_64  goreleaser_Windows_x86_64.zip     (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 goreleaser_Windows_arm64.zip      (PE32+ ARM64, imports kernel32.dll only)
--
-- Note: upstream also publishes `goreleaser_Darwin_all.tar.gz` (53.5 MiB universal);
-- per-arch Darwin tarballs are used here to avoid downloading both architectures.
-- All six archives are flat at root (`goreleaser`/`goreleaser.exe`, `LICENSE.md`,
-- `README.md`, `completions/*`, `manpages/goreleaser.1.gz` with no top-level
-- wrapper directory). `install()` extracts directly from `pkginfo.install_file()`
-- into a clean `install_dir()` so shared `runtimedir` contents from other flat
-- archives cannot leak into goreleaser's payload.

package = {
    spec = "2",

    name = "goreleaser",
    description = "Release engineering, simplified",
    homepage = "https://goreleaser.com",
    authors = {"Carlos Alexandro Becker"},
    maintainers = {"https://github.com/goreleaser/goreleaser/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/goreleaser/goreleaser",
    docs = "https://goreleaser.com/intro/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"release", "packaging", "build", "ci", "cli", "tools"},
    keywords = {"goreleaser", "release", "go", "packaging", "ci", "homebrew", "docker", "nfpm"},

    programs = {"goreleaser"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/goreleaser/goreleaser/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Windows_x86_64.zip",
                            aarch64 = "https://github.com/goreleaser/goreleaser/releases/download/${tag}/goreleaser_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.20.3" },
            ["2.20.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a36d5d7d07a5e538e052cef2a9f93f1cd4af493cf5a3712b9177c1ebe360f0e7",
                    aarch64 = "cfce0afc7bcc14447df211cc10c0012cfc395646070bcf23e840b16cbce6d204",
                },
            },
        },
        macosx = {
            source = "https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.20.3" },
            ["2.20.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8c7ac7f542f3048b2bd87bb49e2f189174087296beee99aad132d58e49660973",
                    aarch64 = "c1423474ab35ab6d7669d87d403dc9ddebf6013a11d3de7309ba840765a19af1",
                },
            },
        },
        windows = {
            source = "https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.20.3" },
            ["2.20.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ef69177888fd7f4048a101f3cca8cc62a56b05b246201798fca5214304ba693d",
                    aarch64 = "77d4be0acc0ece90eb7a067c5b317824c2b99ad7f4636915af2b73f767230219",
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
        exe,
        "LICENSE.md",
        "README.md",
        "completions/goreleaser.bash",
        "completions/goreleaser.fish",
        "completions/goreleaser.zsh",
        "manpages/goreleaser.1.gz",
    }
end

function installed()
    return payload.present(required_files("goreleaser"))
        or payload.present(required_files("goreleaser.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("goreleaser: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        payload.unpack{}
    else
        if not os.isfile(archive) then
            error("goreleaser: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/goreleaser") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/goreleaser"))
        end
    end

    payload.require(required_files(is_win and "goreleaser.exe" or "goreleaser"))
    return true
end

function config()
    xvm.add("goreleaser", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("goreleaser")
    return true
end
