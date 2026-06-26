package = {
    spec = "2",

    -- base info
    name = "package-name",
    description = "Package description",
    type = "package",
    licenses = {"MIT"},
    repo = "https://example.com/repo",

    -- xim pkg info. archs is validated fail-closed against the host arch.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"program1"},
    xvm_enable = true,

    xpm = {
        -- Shape B: per-arch resource map (irregular upstream URLs)
        linux = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                x86_64  = { url = "https://ex/pkg-1.0.0-linux-x86_64.tar.gz", sha256 = "..." },
                aarch64 = { url = "https://ex/pkg-1.0.0-linux-arm64.tar.gz",  sha256 = "..." },
            },
        },
        -- Shape C: URL template + per-arch sha256 (regular URLs).
        -- Placeholders: ${name} ${version} ${os} ${arch} ${arch_alias} ${ext}
        macosx = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                url = "https://ex/${name}-${version}-${os}-${arch_alias}.${ext}",
                sha256 = { x86_64 = "...", aarch64 = "..." },
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
            },
        },
        -- Shape res: XLINGS_RES auto-URL + per-arch checksums
        windows = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                res = true,
                sha256 = { x86_64 = "...", aarch64 = "..." },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- os.arch() returns the canonical host arch (x86_64 / aarch64)
    os.mv("program1", pkginfo.install_dir())
    return true
end

function config()
    xvm.add("package-name")
    return true
end

function uninstall()
    xvm.remove("package-name")
    return true
end
