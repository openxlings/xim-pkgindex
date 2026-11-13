-- Written from dirun's universal package (dirun-<version>-openkal-bundle-all.tar.gz, `mcpp pack
-- dirun --target openkal --mode self-contained --systems all` of the program's ok images over
-- openkal-platform), with the index's own parts added: description, authors, license, the CN mirror.
--
-- One asset serves every system: the package holds the x86_64 and aarch64 images, the launchers
-- bin/dirun and bin/dirun.exe, and okrun for each system it names (libexec/okrun/<os>-<arch>/), so
-- it depends on nothing. GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/dirun, so one sha256 serves both. The emulator (qemu-system-<arch>,
-- qemu-img) is the runner's to name: a platform's runner requires the package that provides it.
package = {
    spec = "2",
    name = "dirun",
    description = "dirun: run one command inside a booted disk image, or boot a payload, and return its output and exit status (one ok-image package for every system)",

    authors = {"Sunrisepeak"},
    maintainers = {"https://github.com/Sunrisepeak/dirun/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/Sunrisepeak/dirun",
    docs = "https://github.com/Sunrisepeak/dirun#readme",
    homepage = "https://github.com/Sunrisepeak/dirun",
    type = "package",
    status = "dev", -- 0.x
    categories = {"runner", "emulator", "testing"},
    keywords = {"qemu", "virtual machine", "runner", "disk image", "firmware", "openkal"},
    archs = {"aarch64", "x86_64"},
    programs = {"dirun"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.3.1" },
            ["0.3.1"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                    ["x86_64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                    ["x86_64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.3.1" },
            ["0.3.1"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                    ["x86_64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                    ["x86_64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.3.1" },
            ["0.3.1"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.1/dirun-0.3.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                    ["x86_64"] = "f1b71ee23f4721412146b54612a67a8fcc47c1ec34a5c5e7810367f6ac061983",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dirun/releases/download/v0.3.0/dirun-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                    ["x86_64"] = "59e5f3d71497e2be8743f1293ef61efa6c17cb1e984c92e87d713c3c21cb2b6d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one top-level directory is the package; it is named
    -- after the archive, which xim unpacks beside it.
    local top = pkginfo.install_file()
    for _, ext in ipairs({ ".tar.gz" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isdir(pkginfo.install_dir())
end

function config()
    local opts = { bindir = path.join(pkginfo.install_dir(), "bin") }
    if os.host() == "windows" then opts.alias = "dirun.exe" end
    -- The package's name is its program (Spec D1).
    xvm.add("dirun", opts)
    return true
end

function uninstall()
    xvm.remove("dirun")
    return true
end
