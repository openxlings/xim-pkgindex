-- Revive - configurable Go linter (canonical upstream: revive-lint/revive).
-- Verified v1.17.1 against GitHub release digests and upstream checksums.txt:
-- Linux amd64/arm64 are static ELF binaries (no interpreter/dynamic section),
-- Darwin amd64/arm64 are Mach-O, and Windows amd64/arm64 are genuine PE32+.
-- All six archives are flat .tar.gz files: revive[.exe], LICENSE, README.md.
-- Explicit-file linting works offline without a Go SDK. Package-pattern/type
-- analysis may use the user's Go toolchain; no SDK is forced on file-only users.

package = {
    spec = "2",
    name = "revive",
    description = "Fast, configurable and extensible Go linter with machine-readable diagnostics",
    homepage = "https://revive.run",
    authors = {"Revive contributors"},
    maintainers = {"revive-lint"},
    licenses = {"MIT"},
    repo = "https://github.com/revive-lint/revive",
    docs = "https://github.com/revive-lint/revive#usage",

    ci = { mirror = true },
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "development", "tools"},
    keywords = {"revive", "go", "golang", "lint", "linter"},
    programs = {"revive"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/revive-lint/revive/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_windows_amd64.tar.gz",
                            aarch64 = "https://github.com/revive-lint/revive/releases/download/${tag}/revive_windows_arm64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/revive-lint/revive/releases/download/v${version}/revive_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.17.1" },
            ["1.17.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c3e6f9d9e2cf7c4039ad5b241a01607c6cc6c61f97e267e6acbb2e7beb373f34",
                    aarch64 = "1445dae6c7337593642b8df73ab9f40a61aff04879de1914bb11a07f9511712e",
                },
            },
        },
        macosx = {
            source = "https://github.com/revive-lint/revive/releases/download/v${version}/revive_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.17.1" },
            ["1.17.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "dad58b913376a5d1cd14f9cea241bbc8b63c8cdae95f85bfe0b569bb8a07f04b",
                    aarch64 = "abdbde1d0e314d9ea7d935eca82dd759e9660fe3b2f1e9157d5357c2ea3b6eb2",
                },
            },
        },
        windows = {
            source = "https://github.com/revive-lint/revive/releases/download/v${version}/revive_windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.17.1" },
            ["1.17.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f995fc51d633b663a89eac71ac8340f4d4286f9d75a6aea2bc5d4096f4562e2e",
                    aarch64 = "2bc6787745198d3f4b435548295bad7cf72c45bffc52721a441224d3631e2cab",
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

local function payload_files(ext)
    return { "revive" .. ext, "LICENSE", "README.md" }
end

function installed()
    return payload.present(payload_files("")) or payload.present(payload_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_windows_") ~= nil or os.getenv("OS") == "Windows_NT"
    local ext = is_win and ".exe" or ""

    os.tryrm(dir)
    fs.mkdir_p(dir)
    if os.isfile(archive) then
        -- payload.unpack handles Windows zip, not these flat tar.gz assets.
        -- Use native bsdtar so a Git/MSYS tar cannot misread drive letters.
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: cmd.exe must see the system tar executable as its first token
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
        end
    elseif os.isfile(parent .. "/revive" .. ext) then
        for _, file in ipairs(payload_files(ext)) do
            os.mv(parent .. "/" .. file, dir .. "/" .. file)
        end
    else
        error("revive: archive not found at " .. archive)
    end
    if not is_win then
        system.exec(string.format('chmod +x "%s/revive"', dir))
    end
    payload.require(payload_files(ext))
    return true
end

function config()
    xvm.add("revive", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("revive")
    return true
end
