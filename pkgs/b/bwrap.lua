package = {
    spec = "1",

    name = "bwrap",
    description = "Bubblewrap — namespace-based sandboxing tool",

    homepage = "https://github.com/containers/bubblewrap",
    contributors = "https://github.com/containers/bubblewrap/graphs/contributors",
    licenses = {"LGPL-2.0-or-later"},
    repo = "https://github.com/containers/bubblewrap",
    docs = "https://github.com/containers/bubblewrap#readme",

    type = "package",
    -- aarch64: a static build of the same source (tools/res/build.sh bwrap),
    -- in the same xlings-res release.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"sandbox", "container", "tool"},
    keywords = {"bwrap", "bubblewrap", "sandbox", "namespace", "rootless"},

    -- `bubblewrap` is the canonical upstream name; `bwrap` is the
    -- compiled binary. We expose both — alias `bubblewrap → bwrap`.
    programs = {"bwrap", "bubblewrap"},
    aliases = {"bubblewrap"},
    xvm_enable = true,

    -- Mirrored at xlings-res/bwrap, built from upstream
    -- containers/bubblewrap v0.11.2 source in Alpine 3.21
    -- (musl libc, libcap-static), with:
    --   meson setup -Dsupport_setuid=true -Drequire_userns=false ...
    -- Single statically-linked ELF (`bin/bwrap`, ~142 KB stripped).
    -- Upstream releases source only — no prebuilt artifact ships
    -- for bwrap, hence the mirror.
    --
    -- Runtime: an ordinary binary, never setuid. A setuid bwrap refuses
    -- overlays (a session that keeps nothing) and cannot forbid nested user
    -- namespaces (a private policy), and installing one asked for sudo on
    -- every machine. Where AppArmor restricts user namespaces, xlings' one
    -- door makes a root-owned copy with one narrow profile (`luban setup`,
    -- `xlings self doctor --isolation --fix`); r1 dropped the chmod 4755.
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/bwrap/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/bwrap/releases/download/<ver>/...


    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/bwrap/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/bwrap/releases/download/${version}/bwrap-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/bwrap/releases/download/${version}/bwrap-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/bwrap/releases/download/${version}/bwrap-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/bwrap/releases/download/${version}/bwrap-${version}-linux-aarch64.tar.gz",
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

            ["latest"] = { ref = "0.11.2" },
            ["0.11.2"] = {
                -- r1: installed as an ordinary binary (no setuid).
                revision = 1,
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bfde1f680ae057b2cbe44e22fa67f79b17e86668301e0c2b4ff725024fd65ff2",
                    aarch64 = "37866fecfdeb3cceb4afebdc6342fe20d05a21f8de72f8cc95adbc0ba3c3ea21",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    os.tryrm(pkginfo.install_dir())
    local bwrapdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(bwrapdir, pkginfo.install_dir())

    return true
end

function config()
    xvm.add("bwrap", { bindir = path.join(pkginfo.install_dir(), "bin") })
    xvm.add("bubblewrap", { bindir = path.join(pkginfo.install_dir(), "bin"), alias = "bwrap" })
    return true
end

function uninstall()
    xvm.remove("bwrap")
    xvm.remove("bubblewrap")
    return true
end
