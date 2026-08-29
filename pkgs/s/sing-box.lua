package = {
    spec = "1",

    name = "sing-box",
    description = "The universal proxy platform",
    homepage = "https://sing-box.sagernet.org/",
    maintainers = {"SagerNet"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://github.com/SagerNet/sing-box",
    -- update only: GitCode rejects an xlings-res/sing-box repo under its
    -- content policy, so the two-forge mirror cannot complete. sing-box still
    -- auto-updates via url_template + latest.ref.
    ci = { update = true },
    docs = "https://sing-box.sagernet.org/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"proxy", "network"},
    keywords = {"proxy", "vpn", "shadowsocks", "vmess", "trojan", "vless"},

    programs = {"sing-box"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/SagerNet/sing-box/releases/download/v{version}/sing-box-{version}-linux-amd64.tar.gz",
            ["latest"] = { ref = "1.13.20" },
            ["1.13.20"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.20/sing-box-1.13.20-linux-amd64.tar.gz",
                sha256 = "646bc01bf128c32a12eb50d8690e387bba7504da7b1d65c704bd53916e38595a",
            },
            ["1.13.11"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.11/sing-box-1.13.11-linux-amd64.tar.gz",
                sha256 = "10ff037632165ca4f6472a0ec21393280ef5a33677e05bcde7fbcf6f9737637b",
            },
        },
        macosx = {
            url_template = "https://github.com/SagerNet/sing-box/releases/download/v{version}/sing-box-{version}-darwin-arm64.tar.gz",
            ["latest"] = { ref = "1.13.20" },
            ["1.13.20"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.20/sing-box-1.13.20-darwin-arm64.tar.gz",
                sha256 = "a5814443f27f14a95ac213d44cc7881540e5d49fa0994981f44a892563346a34",
            },
            ["1.13.11"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.11/sing-box-1.13.11-darwin-arm64.tar.gz",
                sha256 = "8fbeffbd6b737d0d3416428a126cce11002e60c89a006e42f1fbf6906802000b",
            },
        },
        windows = {
            url_template = "https://github.com/SagerNet/sing-box/releases/download/v{version}/sing-box-{version}-windows-amd64.zip",
            ["latest"] = { ref = "1.13.20" },
            ["1.13.20"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.20/sing-box-1.13.20-windows-amd64.zip",
                sha256 = "f2eb3d17bd183d143ef764c8f08c5625a93e628ec4eced24276ed6e9210fb296",
            },
            ["1.13.11"] = {
                url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.11/sing-box-1.13.11-windows-amd64.zip",
                sha256 = "30ecceaebb659195aa67d0a9a398c75c42fb263e079f5499a5f1dcecfa138507",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Each archive extracts into `sing-box-<ver>-<os>-<arch>/` containing
-- the `sing-box` (or `sing-box.exe`) binary plus LICENSE and, on
-- linux/windows, a libcronet shared library used at runtime by the
-- `with_cronet` build tag. We pull just the binary out for the bindir;
-- libcronet is dynamically loaded only when the user enables that
-- feature, which the bundled binary does not (it is built without
-- with_cronet — see release notes), so leaving it behind is safe.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local extracted = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    local exe = is_host("windows") and "sing-box.exe" or "sing-box"
    os.mv(path.join(extracted, exe), path.join(pkginfo.install_dir(), exe))
    os.tryrm(extracted)
    return true
end

function config()
    xvm.add("sing-box", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("sing-box")
    return true
end
