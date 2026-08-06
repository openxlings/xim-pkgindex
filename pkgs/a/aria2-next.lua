package = {
    spec = "2",

    homepage = "https://github.com/AnInsomniacy/aria2-next",
    name = "aria2-next",
    description = "Aria2 Next — a maintained aria2 fork with extensive bug fixes and a modernized architecture",

    authors = {"AnInsomniacy"},
    licenses = {"GPL-2.0"},
    repo = "https://github.com/AnInsomniacy/aria2-next",
    docs = "https://github.com/AnInsomniacy/aria2-next#readme",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "download"},
    keywords = {"aria2", "download", "bt", "torrent", "aria2-next"},

    programs = {"aria2-next"},

    xvm_enable = true,

    -- aria2-next ships standalone per-arch executables on GitHub Releases
    -- (no archive wrapper). The release tag carries a `v` prefix while the
    -- asset name does not, and macOS names its arch `arm64` — so explicit
    -- per-arch resource maps (V2 Shape B) rather than a URL template. Every
    -- sha256 below is from the release's own checksums.sha256 file.
    xpm = {
        linux = {
            ["latest"] = { ref = "2.5.5" },
            ["2.5.5"] = {
                x86_64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-linux-x86_64",
                    sha256 = "b6f2cdadcd34ba16dd7fcb29de4b84c36f893f9b223a9a05157d1892687a45a0",
                },
                aarch64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-linux-aarch64",
                    sha256 = "fd4b07aeb50fb02a9d19dd55e3ff5cea99e5a6263db1cc6a554c216dc49fa987",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2.5.5" },
            ["2.5.5"] = {
                x86_64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-macos-x86_64",
                    sha256 = "49a39dd624d45f693a41ecca0e6359ec0bd91df9efa16cf994f2f200aa45d415",
                },
                aarch64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-macos-arm64",
                    sha256 = "1417eec59edba6ac436b5f3b1bbcc2add01696d62333e8de8c3900677bd45926",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2.5.5" },
            ["2.5.5"] = {
                x86_64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-windows-x86_64.exe",
                    sha256 = "554f2f81ca53731dc9e01710cfb16081a34759f3276ff16eb4b12656c1b6e5b9",
                },
                aarch64 = {
                    url = "https://github.com/AnInsomniacy/aria2-next/releases/download/v2.5.5/aria2-next-2.5.5-windows-arm64.exe",
                    sha256 = "fe029b00c72014690f128c17830f51924b6c07bafee28e28763d1fed93cb393e",
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
    local bin_name = "aria2-next"
    if os.host() == "windows" then
        bin_name = "aria2-next.exe"
    end

    -- The asset is a raw standalone executable (no archive wrapper); move it
    -- into our install dir under the canonical name.
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)
    os.mv(pkginfo.install_file(), path.join(install_dir, bin_name))
    if os.host() ~= "windows" then
        os.exec("chmod +x \"" .. path.join(install_dir, bin_name) .. "\"")
    end
    return os.isfile(path.join(install_dir, bin_name))
end

function config()
    -- The binary is named after the package, so registering the program
    -- doubles as the package-name anchor (no separate group node — a group
    -- under the same name would collide with the program registration).
    xvm.add(package.name, { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
