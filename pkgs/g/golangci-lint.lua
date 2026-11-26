-- golangci-lint - Fast linters runner for Go (golangci/golangci-lint).
--
-- Verified 2026-11-26 against upstream GitHub release v2.15.0 and
-- `golangci-lint-2.15.0-checksums.txt`: every SHA256 below matched both the
-- upstream checksums file and the downloaded release archive bytes:
--   linux/x86_64    golangci-lint-2.15.0-linux-amd64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64   golangci-lint-2.15.0-linux-arm64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64   golangci-lint-2.15.0-darwin-amd64.tar.gz  (Mach-O 64-bit x86_64)
--   macosx/aarch64  golangci-lint-2.15.0-darwin-arm64.tar.gz  (Mach-O 64-bit arm64)
--   windows/x86_64  golangci-lint-2.15.0-windows-amd64.zip    (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 golangci-lint-2.15.0-windows-arm64.zip    (PE32+ ARM64, imports kernel32.dll only)
--
-- Every archive packs a single top-level directory matching the archive stem
-- (`golangci-lint-2.15.0-<os>-<arch>/`) containing `golangci-lint` (or
-- `golangci-lint.exe`), `LICENSE`, and `README.md`.

package = {
    spec = "2",

    name = "golangci-lint",
    description = "Fast linters runner for Go",
    homepage = "https://golangci-lint.run",
    authors = {"golangci"},
    maintainers = {"https://github.com/golangci/golangci-lint/graphs/contributors"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/golangci/golangci-lint",
    docs = "https://golangci-lint.run/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"go", "lint", "cli", "ci", "tools"},
    keywords = {"golangci-lint", "go", "golang", "linter", "static-analysis", "cli"},

    programs = {"golangci-lint"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/golangci/golangci-lint/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/golangci/golangci-lint/releases/download/${tag}/golangci-lint-${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.15.0" },
            ["2.15.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9b7fe6a6bf6334b98decf8d86b11415ea7889afdabdd1959fdce23af2a9ebcea",
                    aarch64 = "b4d8f17068b35ee6060cc2f69a16fb48740d706fbba81661c318649c114a6998",
                },
            },
        },
        macosx = {
            source = "https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.15.0" },
            ["2.15.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "767b899a28285e88ded2823d5dcc4bc5ef681173eb2d80f029a7b17ee4ece3b8",
                    aarch64 = "d1e409481a8ca846c4bc97e781eb5cb1bd5c23353a0b3977a1cbda1b1b6447d5",
                },
            },
        },
        windows = {
            source = "https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "2.15.0" },
            ["2.15.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "cd7ea6063c95de245e17e5246e42bdc14bb221792c429dbd239ab3a6ade6ca6a",
                    aarch64 = "4fb8988abf186158e30af1b8a0fb3671cf2cb02bc91d7e6ce6996f4c1e922e9a",
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
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("golangci-lint"))
        or payload.present(required_files("golangci-lint.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("golangci-lint: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "golangci-lint.exe" or "golangci-lint"

    if is_win or os.isdir(parent .. "/" .. stem) then
        if is_win and not os.isfile(archive) and not os.isdir(parent .. "/" .. stem) then
            error("golangci-lint: neither extracted directory (" .. parent .. "/" .. stem .. ") nor archive (" .. archive .. ") exists")
        end
        payload.unpack{ extracted = stem, strip = 1 }
    elseif os.isfile(archive) then
        os.tryrm(dir)
        fs.mkdir_p(dir)
        system.exec(string.format([[tar -xzf "%s" --strip-components=1 -C "%s"]], normalized, dir))
    else
        error("golangci-lint: neither extracted directory (" .. parent .. "/" .. stem .. ") nor archive (" .. archive .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/golangci-lint") then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/golangci-lint"))
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("golangci-lint", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("golangci-lint")
    return true
end
