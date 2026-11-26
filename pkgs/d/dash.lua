package = {
    spec = "3",
    homepage = "http://gondor.apana.org.au/~herbert/dash/",
    -- base info
    name = "dash",
    description = "Debian Almquist Shell — small POSIX-compliant shell",

    authors = {"Herbert Xu", "Debian"},
    licenses = {"BSD-3-Clause", "GPL-2.0+"},
    repo = "https://git.kernel.org/pub/scm/utils/dash/dash.git",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"shell", "cli", "posix"},
    keywords = {"dash", "shell", "posix", "ash", "debian"},

    -- xvm: xlings version management
    xvm_enable = true,

    programs = { "dash" },

    -- Upstream is source-only on git.kernel.org. The XLINGS_RES tarball is
    -- a fully-static musl-libc build (no glibc runtime dependency), so the
    -- binary is portable across Linux distributions.
    --   Source:  https://git.kernel.org/.../dash.git/snapshot/dash-<ver>.tar.gz
    --   Mirror:  github.com/xlings-res/dash, gitcode.com/xlings-res/dash
    xpm = {
        -- The XLINGS_RES tarball holds `dash-<ver>-linux-x86_64/` (bin, share),
        -- dropped (strip).
        linux = {
            strip = 1,
            ["latest"] = { ref = "0.5.13.3" },
            ["0.5.13.3"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "67b2bb7e149a3d6a54e4984c193d2dc865eba8b23ca5852af96a25cf3fcc0c8d" },
            },
        },
    },
}

import("xim.libxpkg.path")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function config()
    xvm.add("dash", { bindir = path.join(pkginfo.install_dir(), "bin") })
end

function uninstall()
    xvm.remove("dash")
end
