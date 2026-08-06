package = {
    spec = "2",

    homepage = "https://www.7-zip.org",
    name = "7zip",
    description = "7-Zip — a file archiver with a high compression ratio",

    authors = {"Igor Pavlov"},
    licenses = {"LGPL-2.1-or-later"},
    repo = "https://github.com/ip7z/7zip",
    docs = "https://7-zip.org/documentation.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "archiver"},
    keywords = {"7zip", "7z", "compression", "archive"},

    programs = {"7zz", "7z"},

    xvm_enable = true,

    -- 7-Zip ships third-party binaries on GitHub (ip7z/7zip). Per-arch tar.xz
    -- on linux, a single universal tar.xz on macosx (one binary for both
    -- arches), and self-extracting 7z archives (the `.exe` installers) on
    -- windows. Every sha256 below was verified by downloading the asset and
    -- hashing it; no xlings-res mirror exists for this upstream.
    xpm = {
        linux = {
            ["latest"] = { ref = "26.02" },
            ["26.02"] = {
                x86_64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-linux-x64.tar.xz",
                    sha256 = "41aaba7b1235304ab5aa0624530c67ae829496cd29e875925271efdccc28c03e",
                },
                aarch64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-linux-arm64.tar.xz",
                    sha256 = "70ea6cc737ae1495ea2d7eb20ef3120fe579bd3f1a83a9d2362b62ec5bde2bba",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "26.02" },
            ["26.02"] = {
                -- universal binary serves both x86_64 and aarch64
                url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-mac.tar.xz",
                sha256 = "1cf6760579502f87e591ff5c73a005ec50b3e4d6f507e8b038382d563c3175b9",
            },
        },
        windows = {
            ["latest"] = { ref = "26.02" },
            ["26.02"] = {
                x86_64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.exe",
                    sha256 = "6745fa76dc2ea031596d8678f6f6b99c3c1b435b4164a63485adbbc7b8d82ef0",
                },
                aarch64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-arm64.exe",
                    sha256 = "7c6fde79ed5e11b81c7bb6573b7962d3b6322aa5fce69c33ed19f672b55173ab",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local install_dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()

    if os.host() == "windows" then
        -- The windows asset is a 7z self-extracting archive holding 7z.exe /
        -- 7zG.exe / 7zFM.exe directly. `/S /D=` is its documented silent
        -- extract form. Two gotchas: a bare os.exec string trips cmd.exe's
        -- `/c` quote-stripping, and PowerShell's `&` operator does NOT wait
        -- for a GUI-subsystem process — the hook would check for 7z.exe before
        -- the SFX finished. `Start-Process -Wait` fixes both.
        fs.mkdir_p(install_dir)
        os.exec(string.format([[
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%s' -ArgumentList '/S','/D=%s' -Wait | Out-Null"]], archive, install_dir))
        return os.isfile(path.join(install_dir, "7z.exe"))
    end

    -- linux / macosx: the tar.xz expands flat (7zz, docs, license) into the
    -- hook cwd. xlings does not create install_dir for us, and os.mv cannot
    -- create its parent, so mkdir_p first.
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)
    -- xlings may have auto-extracted the archive; if it is still present, do
    -- it here.
    if os.isfile(path.filename(archive)) then
        os.exec("tar -xf " .. path.filename(archive))
        os.tryrm(path.filename(archive))
    end
    os.mv("7zz", path.join(install_dir, "7zz"))
    if os.isfile("7zzs") then
        os.mv("7zzs", path.join(install_dir, "7zzs"))
    end
    if os.isfile("License.txt") then
        os.mv("License.txt", path.join(install_dir, "License.txt"))
    end
    return os.isfile(path.join(install_dir, "7zz"))
end

function config()
    local install_dir = pkginfo.install_dir()

    -- Binding-group root: the package name names no artifact, so `type =
    -- "group"` keeps it from becoming an orphan shim (openxlings/xlings#452).
    xvm.add(package.name, { type = "group" })

    if os.host() == "windows" then
        -- the real binary is 7z.exe; 7zz is an alias shim
        xvm.add("7z", { bindir = install_dir })
        xvm.add("7zz", { bindir = install_dir, alias = "7z" })
    else
        -- the real binary is 7zz; 7z is a convenience alias
        xvm.add("7zz", { bindir = install_dir })
        xvm.add("7z", { bindir = install_dir, alias = "7zz" })
    end
    return true
end

function uninstall()
    xvm.remove("7zz")
    xvm.remove("7z")
    xvm.remove(package.name)
    return true
end
