-- fq: jq for binary formats (wader/fq).
-- Verified 2026-11-27: all six v0.18.0 archives match the GitHub asset
-- digests and upstream checksums.txt. Flat archives contain only fq/fq.exe:
-- Linux static ELF x86-64/AArch64, macOS Mach-O x86_64/arm64, Windows
-- PE32+ x86-64/ARM64. Upstream uses lowercase "macos", not "macosx".
-- LICENSE at tag v0.18.0 is MIT (GitHub's NOASSERTION is not the license).
package = {
    spec = "2",
    name = "fq",
    description = "jq-style queries, decoding, and inspection for binary formats",
    homepage = "https://github.com/wader/fq",
    authors = {"Mattias Wadman"},
    maintainers = {"wader"},
    licenses = {"MIT"},
    repo = "https://github.com/wader/fq",
    docs = "https://wader.github.io/fq/",
    ci = { mirror = true },
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "data", "tools"},
    keywords = {"fq", "jq", "binary", "decode", "json", "query"},
    programs = {"fq"},
    xvm_enable = true,
    extensions = {
        autoupdate = {
            source = "https://github.com/wader/fq/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_macos_amd64.zip",
                            aarch64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_macos_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/wader/fq/releases/download/${tag}/fq_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/wader/fq/releases/download/v${version}/fq_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "07d9407c0cde116f6d9244b5d477a4570c917fef33d6e77c46ed58a38bf5e2b3",
                    aarch64 = "761f857a583c404646701272baa3e7b67ffa961bafd7e325fec184990eeb024f",
                },
            },
        },
        macosx = {
            source = "https://github.com/wader/fq/releases/download/v${version}/fq_${version}_macos_${arch_alias}.zip",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "743cd7527691cd7ab1bdb536b397d226e2775416771f17594075540acd2c017c",
                    aarch64 = "93fc660e455d2f4a64a82555b0b9406fd7bc177a5f9fe3cd638d03e883078cdd",
                },
            },
        },
        windows = {
            source = "https://github.com/wader/fq/releases/download/v${version}/fq_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b255a2f2716a25132607f235e6cb564659ad037eb8bf48d60815edd82f21758d",
                    aarch64 = "420ea5bec0d9e6a5edffbc3d87a3763aa3ac71b756aa5e66a39e8d460a028f12",
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
    return payload.present({ "fq" }) or payload.present({ "fq.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then error("fq: install_file is empty") end
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local dir = pkginfo.install_dir()
    local is_win = normalized:find("_windows_", 1, true) ~= nil
    local exe = is_win and "fq.exe" or "fq"
    os.tryrm(dir)
    fs.mkdir_p(dir)
    -- All upstream archives are flat. Never move the shared download directory.
    if os.isfile(archive) then
        if is_win then
            payload.unpack{}
        elseif normalized:match("%.zip$") then
            system.exec(string.format('unzip -q "%s" -d "%s"', normalized, dir))
        else
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    else
        error("fq: neither archive (" .. archive .. ") nor extracted binary exists")
    end
    payload.require({ exe })
    if not is_win then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end
    return true
end

function config()
    xvm.add("fq", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fq")
    return true
end
