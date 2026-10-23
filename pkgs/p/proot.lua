package = {
    spec = "1",

    name = "proot",
    description = "Userspace chroot, mount --bind, and binfmt_misc — no root required",

    homepage = "https://proot-me.github.io",
    contributors = "https://github.com/proot-me/proot/graphs/contributors",
    licenses = {"GPL-2.0-or-later"},
    repo = "https://github.com/proot-me/proot",
    docs = "https://proot-me.github.io",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"sandbox", "container", "tool"},
    keywords = {"proot", "chroot", "sandbox", "userspace", "rootless"},

    programs = {"proot"},
    xvm_enable = true,

    -- Mirrored at xlings-res/proot, built from upstream proot-me/proot
    -- v5.4.0 source in Alpine 3.20 (musl 1.2.5, gcc 13.2). Single
    -- statically-linked ELF (`bin/proot`) — zero runtime deps. Upstream
    -- ships no v5.4.0 prebuilt; the only release-attached artifact for
    -- proot is the v5.3.0 glibc-static binary, which is why we mirror.
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/proot/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/proot/releases/download/<ver>/...


    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/proot/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/proot/releases/download/${version}/proot-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/proot/releases/download/${version}/proot-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/proot/releases/download/${version}/proot-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/proot/releases/download/${version}/proot-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {

            ["latest"] = { ref = "5.4.0" },
            ["5.4.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f9f4e866fa6ddb09039bed0ae679ab73da9c59086ced57ae132d838033d9f73e",
                    aarch64 = "cd880965713e22c3d7534b32296a4e16ce68b091ebfc32434139dac187f209b9",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    local prootdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(prootdir, pkginfo.install_dir())
    return true
end

function config()
    xvm.add("proot", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("proot")
    return true
end
