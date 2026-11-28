-- Official single-binary releases only; no config or community cheatsheets are created.
-- POSIX .gz assets are compressed executables, NOT tarballs (same landing as dasel).
-- 5.1.0 has no "v" tag prefix. Downloaded bytes match GitHub's release SHA256 digests.
-- Linux binaries are static Go ELFs. Windows ARM64 has no upstream release asset;
-- BSD/Solaris and 32-bit assets are outside this package's supported platform matrix.
package = {
    spec = "2",
    name = "cheat",
    description = "Create and view interactive command-line cheatsheets",
    homepage = "https://github.com/cheat/cheat",
    authors = {"Christopher Allen Lane and contributors"},
    maintainers = {"cheat"},
    licenses = {"MIT"},
    repo = "https://github.com/cheat/cheat",
    docs = "https://github.com/cheat/cheat#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "cli"},
    keywords = {"cheat", "cheatsheets", "documentation", "terminal"},
    programs = {"cheat"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/cheat/cheat/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/cheat/cheat/releases/download/${tag}/cheat-linux-amd64.gz",
                            aarch64 = "https://github.com/cheat/cheat/releases/download/${tag}/cheat-linux-arm64.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/cheat/cheat/releases/download/${tag}/cheat-darwin-amd64.gz",
                            aarch64 = "https://github.com/cheat/cheat/releases/download/${tag}/cheat-darwin-arm64.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/cheat/cheat/releases/download/${tag}/cheat-windows-amd64.exe.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/cheat/cheat/releases/download/${version}/cheat-linux-${arch_alias}.gz",
            ["latest"] = { ref = "5.1.0" },
            ["5.1.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8c8405574d51d63ee89594bfed241f478d507d96af78e5c370dcbe65633d7b34",
                    aarch64 = "78fd70fedd7c2cd297af827c29c495c8f6d2b9a880739450ac13e18eefa2f17b",
                },
            },
        },
        macosx = {
            source = "https://github.com/cheat/cheat/releases/download/${version}/cheat-darwin-${arch_alias}.gz",
            ["latest"] = { ref = "5.1.0" },
            ["5.1.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d99884c698d10f0b191deac969190c2b5311a8202f4f8c394130969f9adb8309",
                    aarch64 = "4fcc9ef5b2b3ae31d3f9c77dc6492a4336592c34c60d8a20814fb6155642b37c",
                },
            },
        },
        windows = {
            source = "https://github.com/cheat/cheat/releases/download/${version}/cheat-windows-amd64.exe.zip",
            ["latest"] = { ref = "5.1.0" },
            ["5.1.0"] = {
                sha256 = {
                    x86_64 = "a7fbdb2c02d575c2d75aa350ac25006699586edccbfce2304a01b5f518e06b80",
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
    return payload.present({ "cheat" }) or payload.present({ "cheat.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then error("cheat: install_file is empty") end
    local normalized = archive:gsub("\\", "/")
    local dir = pkginfo.install_dir()
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "cheat.exe" or "cheat"
    local target = dir .. "/" .. exe

    if is_win then
        local stem = (normalized:match("([^/]+)$") or ""):gsub("%.zip$", "")
        payload.unpack{ extracted = stem }
        os.mv(dir .. "/cheat-windows-amd64.exe", target)
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        local unpacked = normalized:gsub("%.gz$", "")
        if unpacked ~= normalized and os.isfile(unpacked) then
            os.mv(unpacked, target)
        elseif normalized:match("%.gz$") and os.isfile(archive) then
            system.exec(string.format([[sh -c 'gzip -dc "$1" > "$2"' _ "%s" "%s"]], normalized, target))
        elseif os.isfile(archive) then
            os.mv(archive, target)
        else
            error("cheat: archive not found: " .. archive)
        end
        if os.isfile(target) then
            system.exec(string.format([[chmod +x "%s"]], target))
        end
    end
    payload.require({ exe })
    return true
end

function config()
    xvm.add("cheat", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cheat")
    return true
end
