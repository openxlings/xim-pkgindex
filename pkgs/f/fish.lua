package = {
    spec = "2",

    name = "fish",
    description = "Friendly interactive shell — smart, user-friendly, modern command-line",
    homepage = "https://fishshell.com",
    maintainers = {"fish-shell"},
    licenses = {"GPL-2.0"},
    repo = "https://github.com/fish-shell/fish-shell",
    ci = { mirror = true, update = true },
    docs = "https://fishshell.com/docs/current/",

    type = "package",
    -- xpm only carries the x86_64 url; mark x86_64 to keep arch metadata
    -- honest. aarch64 is published upstream too — add it here once
    -- xpm gains a per-arch url shape.
    archs = {"x86_64"},
    status = "stable",
    categories = {"shell", "cli"},
    keywords = {"fish", "shell", "interactive", "rust"},

    -- Upstream ships a single self-contained binary (static-pie linked,
    -- no glibc/musl runtime dep), so the only declared program is `fish`.
    programs = {"fish"},
    xvm_enable = true,

    -- 4.6.0 ships static-pie binaries on linux only; the macOS release
    -- tarballs are .app bundles / .pkg installers (not flat CLI tarballs)
    -- and Windows is upstream-unsupported, so this xpkg is linux-only.
    xpm = {
        linux = {
            url_template = "https://github.com/fish-shell/fish-shell/releases/download/{version}/fish-{version}-linux-x86_64.tar.xz",
            ["latest"] = { ref = "4.8.0" },
            ["4.8.0"] = {
                url = "https://github.com/fish-shell/fish-shell/releases/download/4.8.0/fish-4.8.0-linux-x86_64.tar.xz",
                sha256 = "98f7916878fc76be797cabf284f185b56f31a35681e3aec9b9faf7a4a6aa0d74",
            },
            ["4.6.0"] = {
                url = "https://github.com/fish-shell/fish-shell/releases/download/4.6.0/fish-4.6.0-linux-x86_64.tar.xz",
                sha256 = "497c9c4e3fb3c006fe9d2c9a5a5447c1c90490b6b4ce6bfaf75e53b495c82f36",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The fish-<ver>-linux-<arch>.tar.xz archives are flat: a single `fish`
-- binary lands directly in the runtime download dir, with no enclosing
-- folder. Mirror the fzf pattern: explicitly mv the bare binary into a
-- fresh install_dir so xlings's auto-stage (which sees an empty install_dir
-- otherwise) doesn't pull unrelated runtimedir entries in.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    local download_dir = path.directory(pkginfo.install_file())
    os.mv(path.join(download_dir, "fish"), path.join(pkginfo.install_dir(), "fish"))
    return true
end

function config()
    xvm.add("fish", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fish")
    return true
end
