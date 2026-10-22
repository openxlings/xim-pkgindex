package = {
    spec = "1",

    name = "virtiofsd",
    description = "virtiofsd: a vhost-user virtio-fs device backend, how a VM shares host directories (static)",

    homepage = "https://virtio-fs.gitlab.io",
    repo = "https://gitlab.com/virtio-fs/virtiofsd",
    licenses = {"Apache-2.0", "BSD-3-Clause"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"virtualization", "tool"},
    keywords = {"virtiofs", "virtio-fs", "vhost-user", "qemu", "luban", "machine"},

    -- How a Luban machine shares its files (xlings design 2026-10-21 §4): one
    -- unprivileged virtiofsd a share, started by the machine's supervisor,
    -- installed the first time a machine starts. Built static from upstream's
    -- tag, on each architecture, by this index (tools/res/build.sh virtiofsd).
    programs = {"virtiofsd"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.14.0" },
            ["1.14.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "55c2cec89dd2b2ba97e79e5d0f2fd583e66ede88f9d18a05b699728a388d9c1e",
                    aarch64 = "4cc09edb39e026a94b14bc44605ec7cb49617c0cffa652fedf04f9ab967bd3f3",
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
    return os.isfile(path.join(dir, "bin", "virtiofsd"))
end

function config()
    xvm.add("virtiofsd", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("virtiofsd")
    return true
end
