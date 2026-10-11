package = {
    spec = "1",

    name = "passt",
    description = "passt and pasta: user-mode networking for VMs and network namespaces (static)",

    homepage = "https://passt.top",
    repo = "https://passt.top/passt",
    licenses = {"GPL-2.0-or-later", "BSD-3-Clause"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "sandbox", "tool"},
    keywords = {"passt", "pasta", "network", "namespace", "rootless", "subos"},

    -- What a SubOS with `net=nat` gets its network from (xlings: pasta). Built
    -- static from upstream's tag, on each architecture, by this index
    -- (tools/res/build.sh passt): nothing for a machine to install.
    -- Upstream versions are <date>.<commit>.
    programs = {"pasta", "passt"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2026_10_02.cba3570" },
            ["2026_10_02.cba3570"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5d5510b7a84dcb4e28d4926e9018f33197d040b7fc5dd1e9c89d243ae67269ad",
                    aarch64 = "6154969bfe23a216de2aec7986f2847c8a22b3aa27972d7447f87329ae31ebee",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", "pasta"))
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add("pasta", { bindir = bindir })
    xvm.add("passt", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("pasta")
    xvm.remove("passt")
    return true
end
