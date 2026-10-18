package = {
    spec = "1",

    name = "xdesk",
    description = "xdesk: the Luban OS desktop -- a compositor and shell over wlroots, classic (tiled) and canvas profiles, no GPU needed",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"desktop", "wayland", "luban"},
    keywords = {"xdesk", "wayland", "compositor", "desktop", "canvas", "tile", "luban"},

    -- The desktop of the desktop editions (xlings: Luban OS desktop part 2),
    -- released with xlings at the same date version (openxlings/xlings,
    -- tools/xdesk_release.sh; mirrored to xlings-res/xdesk). A glibc program:
    -- its wlroots libraries (libwayland, libdrm, libffi) are private, in
    -- libexec/lib -- not lib/, which an environment's projection would put
    -- beside its own Mesa -- and an install patches it onto the index's glibc
    -- and gcc-runtime with that directory on its RPATH. It is a session the
    -- freedesktop way (share/wayland-sessions: xdesk-classic, xdesk-canvas,
    -- which speak opensal themselves); its profiles' defaults are data
    -- (share/xdesk/<profile>.ini), under a system's /etc/xdg/xdesk and a
    -- person's ~/.config/xdesk. Its terminal is foot (xim:labwc-desktop
    -- carries one, with fonts).
    programs = {"xdesk"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.44",
                "xim:gcc-runtime",
            },
            ["latest"] = { ref = "2026.10.17.1" },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "349eba210386ac55e7978749a82add6c23f9e6774b9d136e7bf21b6dcfbd7962",
                },
            },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "70ed24a0455300438c8fe7784100a5a1ae1a1a88da039de10c092b58177fe6ae",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d4d3f6f665ed89bbc6a88333348473b983ba63bb9ba443caab21cb90d5c6d13c",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "68d3a5114dd2345b0c8cc9ef8872767409fe2244bb6bf909b01471b4a8a09d9d",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9d5e68ca172c09a60352165c09a572b24ff72cac5bd2fce6bc88bb6d8739d026",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "705e0893a8043b1aefce39c4d389e8a7adf0cd18da10f4959d6a6cacc6555374",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1b2b22fd32bc7bd997111f7bd4c41d71d407be61783b45bff86df0841d1524cf",
                },
            },
            ["2026.10.13.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "10cf1abefaa72b8eaec2a9b7f9ae572c1941423e5b16290ec4117a0ba02ba380",
                },
            },
            ["2026.10.13.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e9026a885e93e2b7d27e098956a74b977a697e7c981bbfd767c99516524ec6a8",
                },
            },
            ["2026.10.13.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ac9b6aaf80db188f620ca6407d7e449ce6a17aeef1a70819bcc02f3878e8cf97",
                },
            },
            ["2026.10.13.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "24bb7e747f7235eb4eb16d045e3eea7a52aa56b8af97276a7d9894802c8ec6a9",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.elfpatch")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    -- glibc's loader, and the private libraries on the RPATH too.
    elfpatch.set({
        interp_from = "linux-x86_64-glibc",
        extra_rpath = { path.join(dir, "libexec", "lib") },
    })
    return os.isfile(path.join(dir, "bin", "xdesk"))
       and os.isfile(path.join(dir, "share", "wayland-sessions", "xdesk-classic.desktop"))
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()
    -- The program is the package's own name: registered as it, the files bound to it.
    xvm.add("xdesk", { bindir = path.join(pkginfo.install_dir(), "bin") })
    -- The sessions, where a desktop's manager (and the Luban OS window)
    -- looks; the profiles' defaults, where xdesk does.
    if xvm.files then
        xvm.files{ src = "share/wayland-sessions", dst = "share/wayland-sessions", binding = binding }
        xvm.files{ src = "share/xdesk", dst = "share/xdesk", binding = binding }
    end
    return true
end

function uninstall()
    xvm.remove("xdesk")
    return true
end
