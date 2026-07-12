package = {
    spec = "1",

    name = "bat",
    description = "A cat clone with syntax highlighting and Git integration",
    homepage = "https://github.com/sharkdp/bat",
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/bat",
    docs = "https://github.com/sharkdp/bat#readme",

    -- CI automation opt-in (metadata only; ignored by libxpkg/installer).
    -- mirror: publish the declared version to xlings-res after merge.
    -- update: enroll in the central scanner to PR new upstream releases.
    ci = { mirror = true, update = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "viewer", "tools"},
    keywords = {"cat", "bat", "syntax-highlighting", "rust"},

    programs = {"bat"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/sharkdp/bat/releases/download/v{version}/bat-v{version}-x86_64-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.26.1" },
            ["0.26.1"] = {
                url = "https://github.com/sharkdp/bat/releases/download/v0.26.1/bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "0dcd8ac79732c0d5b136f11f4ee00e581440e16a44eab5b3105b611bbf2cf191",
            },
        },
        macosx = {
            url_template = "https://github.com/sharkdp/bat/releases/download/v{version}/bat-v{version}-aarch64-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.26.1" },
            ["0.26.1"] = {
                url = "https://github.com/sharkdp/bat/releases/download/v0.26.1/bat-v0.26.1-aarch64-apple-darwin.tar.gz",
                sha256 = "e30beff26779c9bf60bb541e1d79046250cb74378f2757f8eb250afddb19e114",
            },
        },
        windows = {
            url_template = "https://github.com/sharkdp/bat/releases/download/v{version}/bat-v{version}-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.26.1" },
            ["0.26.1"] = {
                url = "https://github.com/sharkdp/bat/releases/download/v0.26.1/bat-v0.26.1-x86_64-pc-windows-msvc.zip",
                sha256 = "0f729b4b6f5f28d395c641eacc2e9ff68d0096b85aa0eec344aa62425144b69b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archives extract into `bat-v<ver>-<triple>/` containing the `bat` /
-- `bat.exe` binary alongside autocomplete scripts, manpages and docs.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local extracted = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")

    local exe = is_host("windows") and "bat.exe" or "bat"
    os.mv(path.join(extracted, exe), path.join(pkginfo.install_dir(), exe))
    os.tryrm(extracted)
    return true
end

function config()
    xvm.add("bat", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("bat")
    return true
end
