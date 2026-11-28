-- Hugo - fast and flexible static site generator built with Go.
--
-- Platform and architecture coverage (verified against gohugoio/hugo v0.170.1):
--   linux    x86_64, aarch64   hugo_<ver>_linux-{amd64,arm64}.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   hugo_<ver>_darwin-universal.pkg        (signed component pkg, Mach-O fat arm64+x86_64)
--   windows  x86_64, aarch64   hugo_<ver>_windows-{amd64,arm64}.zip   (PE binary, imports kernel32.dll only)
--
-- Note: from Hugo v0.170.0, upstream dropped the separate CGO-enabled `extended`
-- edition and ships one unified static Hugo binary across all platforms.
-- Every SHA256 below was verified against both upstream `hugo_0.170.1_checksums.txt`
-- and downloaded release assets.

package = {
    spec = "2",

    name = "hugo",
    description = "Fast and flexible static site generator built with Go",
    homepage = "https://gohugo.io",
    authors = {"Bjørn Erik Pedersen", "Steve Francia"},
    maintainers = {"https://github.com/gohugoio/hugo"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/gohugoio/hugo",
    docs = "https://gohugo.io/documentation/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "ssg", "cli", "tools"},
    keywords = {"hugo", "ssg", "static-site-generator", "markdown", "web", "go"},

    programs = {"hugo"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/gohugoio/hugo/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_linux-amd64.tar.gz",
                            aarch64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_darwin-universal.pkg",
                            aarch64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_darwin-universal.pkg",
                        },
                        windows = {
                            x86_64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_windows-amd64.zip",
                            aarch64 = "https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/gohugoio/hugo/releases/download/v${version}/hugo_${version}_linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.170.1" },
            ["0.170.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "841a5462853aefc9942e4de1e8a5d75584b6a5181941e6ad3f1d745190e03cd8",
                    aarch64 = "6f57f13bc47c000c0d36c7f5a446d6c06f7956d8e102cc2a13735e0c0225b2d2",
                },
            },
        },
        macosx = {
            source = "https://github.com/gohugoio/hugo/releases/download/v${version}/hugo_${version}_darwin-universal.pkg",
            ["latest"] = { ref = "0.170.1" },
            ["0.170.1"] = {
                sha256 = {
                    x86_64 = "f7672f5e47f13c488ecd9ae96450ed9d2044629d60fe23570312e896c1918d73",
                    aarch64 = "f7672f5e47f13c488ecd9ae96450ed9d2044629d60fe23570312e896c1918d73",
                },
            },
        },
        windows = {
            source = "https://github.com/gohugoio/hugo/releases/download/v${version}/hugo_${version}_windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.170.1" },
            ["0.170.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e4a8bec642b5d18f451452fafb318bbb6b7f09e5208f3dca76a204c888c9e072",
                    aarch64 = "5d19b657ec60144f75cd326d9e82a0e55fcd72e8e4ed178562ddd5856b6e1757",
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
    return payload.present({ "hugo" }) or payload.present({ "hugo.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("hugo: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local is_pkg = normalized:match("%.pkg$") ~= nil
    local exe = is_win and "hugo.exe" or "hugo"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("hugo: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    elseif is_pkg then
        -- macOS upstream ships a signed component .pkg whose cpio Payload holds ./hugo.
        if os.isfile(archive) then
            local pkg_tmp = dir .. "/._pkg"
            os.tryrm(pkg_tmp)
            system.exec(string.format([[pkgutil --expand-full "%s" "%s"]], normalized, pkg_tmp))
            local candidates = {
                pkg_tmp .. "/Payload/hugo",
                pkg_tmp .. "/Payload/usr/local/bin/hugo",
            }
            local moved = false
            for _, src in ipairs(candidates) do
                if os.isfile(src) then
                    os.mv(src, dir .. "/hugo")
                    moved = true
                    break
                end
            end
            os.tryrm(pkg_tmp)
            if not moved then
                error("hugo: extracted binary not found inside " .. normalized)
            end
        elseif os.isfile(parent .. "/hugo") then
            os.mv(parent .. "/hugo", dir .. "/hugo")
        else
            error("hugo: neither pkg archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/hugo") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/hugo"))
        end
    else
        -- Upstream Linux archives are flat (no top-level wrapper directory). Extract
        -- directly into install_dir so files from unrelated flat packages in the
        -- shared download directory cannot leak into this payload.
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/hugo") then
            os.mv(parent .. "/hugo", dir .. "/hugo")
        else
            error("hugo: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/hugo") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/hugo"))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local cfg = { bindir = dir }
    if os.isfile(dir .. "/hugo.exe") then
        cfg.alias = "hugo.exe"
    end
    xvm.add("hugo", cfg)
    return true
end

function uninstall()
    xvm.remove("hugo")
    return true
end
