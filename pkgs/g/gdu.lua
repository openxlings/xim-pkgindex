-- gdu: fast disk usage analyzer (dundee/gdu).
-- v5.39.0: all six archives contain one architecture-named executable at root.
-- Both Linux ELFs have no interpreter or dynamic section (including the arm64
-- asset without "static" in its name); no runtime deps are required. Both
-- Windows PEs import only kernel32.dll, with no delay imports. macOS uses the
-- official amd64/arm64 Mach-O binaries. Rename each payload to gdu[.exe].
-- SHA-256 verified against upstream sha256sums.txt and GitHub asset digests.

package = {
    spec = "2",
    name = "gdu",
    description = "Fast disk usage analyzer with console interface and non-interactive output",
    homepage = "https://github.com/dundee/gdu",
    authors = {"Daniel Milde"},
    maintainers = {"dundee"},
    licenses = {"MIT"},
    repo = "https://github.com/dundee/gdu",
    docs = "https://github.com/dundee/gdu#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "tools", "filesystem"},
    keywords = {"gdu", "disk-usage", "disk", "du", "go"},
    programs = {"gdu"},
    xvm_enable = true,

    -- Official GLOBAL assets only; no CN mirror has been verified.
    -- Do not opt into ci.mirror: its materializer does not support upstream .tgz.
    extensions = {
        autoupdate = {
            source = "https://github.com/dundee/gdu/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_linux_amd64_static.tgz",
                            aarch64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_linux_arm64.tgz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_darwin_amd64.tgz",
                            aarch64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_darwin_arm64.tgz",
                        },
                        windows = {
                            x86_64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_windows_amd64.exe.zip",
                            aarch64 = "https://github.com/dundee/gdu/releases/download/${tag}/gdu_windows_arm64.exe.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "5.39.0" },
            ["5.39.0"] = {
                x86_64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_linux_amd64_static.tgz",
                    sha256 = "7e1036cba1696ecceda40ff79dacd43db9c157fa137ea5d50e4a198b047418a1",
                },
                aarch64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_linux_arm64.tgz",
                    sha256 = "95900a16b9f9dad97f975b667644ddc073a1b377e95a0b4dfdf50045bf556ad0",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "5.39.0" },
            ["5.39.0"] = {
                x86_64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_darwin_amd64.tgz",
                    sha256 = "b3b966daaa18f743f4d25c194fe22b383c5232e437c39e3875712ef9a78115ec",
                },
                aarch64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_darwin_arm64.tgz",
                    sha256 = "320a43faaa4e57928218292f70941581f334768477f337c641dd01aa8c904ba8",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "5.39.0" },
            ["5.39.0"] = {
                x86_64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_windows_amd64.exe.zip",
                    sha256 = "2c2c28a4edeb1a2742076ede3a0fc7851589d482c8cf679f293faa17ed9888b9",
                },
                aarch64 = {
                    url = "https://github.com/dundee/gdu/releases/download/v5.39.0/gdu_windows_arm64.exe.zip",
                    sha256 = "811748098f890bb9f86c76025199856914c8d8329b6cc13b3293a92b816c6f10",
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

function installed()
    return payload.present({ "gdu" }) or payload.present({ "gdu.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local name = assert(archive:gsub("\\", "/"):match("([^/]+)$"), "gdu: install_file is empty")
    local is_win = name:match("%.zip$") ~= nil
    local original = name:gsub("%.tgz$", ""):gsub("%.zip$", "")
    local dir = pkginfo.install_dir()
    local exe = is_win and "gdu.exe" or "gdu"

    -- Extract into our own clean directory, never move the shared download dir.
    if is_win then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
    end
    payload.require({ original })
    os.mv(dir .. "/" .. original, dir .. "/" .. exe)
    if not is_win then shell.exec({ "chmod", "+x", dir .. "/" .. exe }) end
    payload.require({ exe })
    return true
end

function config()
    xvm.add("gdu", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gdu")
    return true
end
