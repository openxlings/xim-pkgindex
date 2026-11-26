-- Infracost - Cloud cost estimates for Terraform (binary: `infracost`).
--
-- Verified 2026-11-26 against upstream release v0.10.51: every SHA256 below was
-- verified against `<asset>.sha256` and downloaded archives. The four POSIX
-- `.tar.gz` archives each pack a single binary named `infracost-<os>-<arch>`
-- (renamed to `infracost` on install); both Windows `.zip` archives pack a
-- flat `infracost.exe`. Linux binaries (x86_64 and aarch64) are statically
-- linked Go executables (`readelf -d`: no NEEDED); Windows PE32+ binaries
-- (x86_64 and arm64) import only `kernel32.dll`.
package = {
    spec = "2",

    name = "infracost",
    description = "Cloud cost intelligence for engineers, AI coding agents, and CI/CD",
    homepage = "https://infracost.io",
    authors = {"Infracost"},
    maintainers = {"https://github.com/infracost/infracost/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/infracost/infracost",
    docs = "https://www.infracost.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"devops", "iac", "cloud", "cli", "tools"},
    keywords = {"infracost", "terraform", "finops", "cloud", "cost"},

    programs = {"infracost"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/infracost/infracost/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-windows-amd64.zip",
                            aarch64 = "https://github.com/infracost/infracost/releases/download/${tag}/infracost-windows-arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/infracost/infracost/releases/download/v${version}/infracost-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.10.51" },
            ["0.10.51"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "aa4a308eb24ad8e177780cea015a7501bfd511ed1e658e1bd9a6c1f55c2334b5",
                    aarch64 = "2ac5d00b54365c18aa148d0f715ed4f8548b0d158ca7409ebae0b7ab3f1e6663",
                },
            },
        },
        macosx = {
            source = "https://github.com/infracost/infracost/releases/download/v${version}/infracost-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.10.51" },
            ["0.10.51"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8e35ae95a5ec2ebc05969b1bc5c36a2f8704fab8d036f8af939359e6b4657ad8",
                    aarch64 = "3c26767efa9cbd1b392ed2be7b67c3ac02401785387dd3a9954602ad0b4576c8",
                },
            },
        },
        windows = {
            source = "https://github.com/infracost/infracost/releases/download/v${version}/infracost-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.10.51" },
            ["0.10.51"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f2b6d290d8e4214bfb23ed3b7fd85324dfe0552c689b1920ff0f7f70d374dd9d",
                    aarch64 = "17d41eda4c96c5166de3ad09b0646c29ac9c6397425e6ebad092e57a52c72513",
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
    return payload.present({ "infracost" })
        or payload.present({ "infracost.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("infracost: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:match("^(.+)%.tar%.gz$")
    local is_win = is_windows()
    local exe = is_win and "infracost.exe" or "infracost"

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        if not os.isfile(dir .. "/infracost") and stem and os.isfile(dir .. "/" .. stem) then
            os.mv(dir .. "/" .. stem, dir .. "/infracost")
        end
        shell.exec({ "chmod", "+x", dir .. "/infracost" })
    elseif stem and os.isfile(parent .. "/" .. stem) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. stem, dir .. "/infracost")
        shell.exec({ "chmod", "+x", dir .. "/infracost" })
    elseif os.isfile(parent .. "/infracost") then
        fs.mkdir_p(dir)
        os.mv(parent .. "/infracost", dir .. "/infracost")
        shell.exec({ "chmod", "+x", dir .. "/infracost" })
    else
        error("infracost: archive not found at " .. archive .. " and no extracted binary in " .. parent)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("infracost", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("infracost")
    return true
end
