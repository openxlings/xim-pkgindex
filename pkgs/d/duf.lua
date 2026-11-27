-- duf: read-only disk usage/free information (muesli/duf), not sigoden/dufs.
-- v0.9.1 official archives are flat: duf (duf.exe on Windows) and duf.1.
-- Linux x86_64/aarch64 ELFs are static (no .dynamic); Windows x86_64/ARM64
-- imports only kernel32.dll, with no delay imports or external runtime.
-- macOS has native x86_64/ARM64 archives. Other upstream CPU/BSD targets
-- are outside this index's supported platform/architecture matrix.
-- Upstream LICENSE is MIT with BSD-3-Clause notices for copied gopsutil code.

package = {
    spec = "2",
    name = "duf",
    description = "Disk usage/free utility with readable tables and JSON output",
    homepage = "https://github.com/muesli/duf",
    repo = "https://github.com/muesli/duf",
    docs = "https://github.com/muesli/duf#readme",
    maintainers = {"muesli"},
    licenses = {"MIT", "BSD-3-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "tools", "filesystem"},
    keywords = {"duf", "disk", "usage", "free", "filesystem", "json"},
    programs = {"duf"},
    xvm_enable = true,

    -- Only official upstream assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/muesli/duf/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_windows_x86_64.zip",
                            aarch64 = "https://github.com/muesli/duf/releases/download/${tag}/duf_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.9.1" },
            ["0.9.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5add851e7062c5e56939abb664705e4d14fa2d06289490aff31d51f153832de7",
                    aarch64 = "22ea0ad29f6610bf443aa351e600de97e47a9b380ef58316606a84bb8f595216",
                },
            },
        },
        macosx = {
            source = "https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.9.1" },
            ["0.9.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e3384519b0055c904b7352b55cd81bd101f5dd94dab1195a72880bddca7c2aaf",
                    aarch64 = "512ba0ff3585bb8c65841de557a4c4b8712332db005dc952fa98d373a05d01df",
                },
            },
        },
        windows = {
            source = "https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.9.1" },
            ["0.9.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "503934be81f847d9ddb1b739834217480633435ad16515dd199e372c0b2e1afc",
                    aarch64 = "6aa91380c7bd5ba935bab38bb826680255a0d9569614de7b0d149cea471ccf4b",
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
    return payload.present({ "duf", "duf.1" })
        or payload.present({ "duf.exe", "duf.1" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local windows = archive:lower():match("%.zip$") ~= nil
    local exe = windows and "duf.exe" or "duf"

    -- Extract into this package only, not the shared flat-archive runtime dir.
    if windows then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    end
    payload.require({ exe, "duf.1" })
    return true
end

function config()
    xvm.add("duf", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("duf")
    return true
end
