package = {
    spec = "2",

    homepage = "https://www.7-zip.org",
    name = "7zip",
    description = "7-Zip — a file archiver with a high compression ratio; on windows the install directory also carries 7z.dll for programs (e.g. via bit7z) that link the 7-Zip library instead of shelling out to the CLI",

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
    --
    -- WINDOWS ALSO CARRIES 7z.dll. The `.exe` asset is upstream's official
    -- full installer (not a console-only distribution), and its silent
    -- install below (`/S /D=`) lays down `7z.dll` at the install root
    -- alongside `7z.exe` -- the shared library upstream ships for programs
    -- that link 7-Zip instead of shelling out to it (e.g. via bit7z), with
    -- every format 7-Zip itself reads, including RAR extraction. This is a
    -- STATED CONVENTION of this recipe: a consumer that wants the library
    -- reads it from `<install_dir>/7z.dll`, not from PATH. Licence for that
    -- code is LGPL-2.1-or-later, WITH the unRAR restriction on the RAR
    -- decoder specifically (upstream's own DOC/License.txt) -- linking
    -- 7z.dll does not waive that restriction.
    --
    -- Linux/macOS upstream ships only the `7zz` CLI binary; there is no
    -- shared library asset on those platforms (no `lib7zip.so`/`.dylib` in
    -- the archives below), so this is a Windows-only distinction.
    extensions = {
        autoupdate = {
            source = "https://github.com/ip7z/7zip/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/ip7z/7zip/releases/download/${version}/7z${version:compact}-linux-arm64.tar.xz",
                            x86_64 = "https://github.com/ip7z/7zip/releases/download/${version}/7z${version:compact}-linux-x64.tar.xz",
                        },
                        macosx = "https://github.com/ip7z/7zip/releases/download/${version}/7z${version:compact}-mac.tar.xz",
                        windows = {
                            aarch64 = "https://github.com/ip7z/7zip/releases/download/${version}/7z${version:compact}-arm64.exe",
                            x86_64 = "https://github.com/ip7z/7zip/releases/download/${version}/7z${version:compact}-x64.exe",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "26.05" },
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
            ["26.05"] = {
                aarch64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-linux-arm64.tar.xz",
                    sha256 = "0b71f6cfc34669b3bf69f2347efd3429f77020665003a13b9cdc53b784270421",
                },
                x86_64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-linux-x64.tar.xz",
                    sha256 = "22cf82fcc6eb7474f1d5bb4f02c0f8ebd573a718089d6833dc30f8350a3b232e",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "26.05" },
            ["26.02"] = {
                -- universal binary serves both x86_64 and aarch64
                url = "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-mac.tar.xz",
                sha256 = "1cf6760579502f87e591ff5c73a005ec50b3e4d6f507e8b038382d563c3175b9",
            },
            ["26.05"] = {
                url = "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-mac.tar.xz",
                sha256 = "12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570",
            },
        },
        windows = {
            ["latest"] = { ref = "26.05" },
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
            ["26.05"] = {
                aarch64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-arm64.exe",
                    sha256 = "86d5790d5dd84cab4636c3bb7fab10d3ed7cd3e57e6119401bd2769e28165268",
                },
                x86_64 = {
                    url = "https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.exe",
                    sha256 = "fd99e86f57d8f429ef5ed045bf98315af962e2309b0f1ba87a147a44c71647d0",
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
        -- exec-quoting-ok: both values are inside PowerShell's single-quoted arguments
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
