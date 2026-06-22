package = {
    spec = "1",

    name = "patchelf",
    description = "ELF patch tool for interpreter and RPATH",

    homepage = "https://github.com/NixOS/patchelf",
    maintainers = {"NixOS"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://github.com/NixOS/patchelf",
    docs = "https://github.com/NixOS/patchelf",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"elf", "binary", "tool"},
    keywords = {"elfpatch", "patchelf", "rpath", "interpreter"},

    programs = {"patchelf"},
    aliases = {"elfpatch"},
    xvm_enable = true,

    -- The upstream NixOS/patchelf release tarball
    -- (`patchelf-<ver>-x86_64.tar.gz`) extracts *flat* — `./bin/`, `./share/`,
    -- with no top-level directory — so xlings's stock install hook
    -- (`os.mv(<file-basename>, install_dir)`) cannot find the expected
    -- `patchelf-<ver>-…/` directory and the install fails.
    --
    -- We mirror at xlings-res/patchelf, repackaged with a single
    -- top-level directory `patchelf-<ver>-linux-x86_64/` matching the
    -- xlings-res tarball convention `<pkg>-<ver>-<platform>-<arch>/`.
    -- Binaries inside are byte-identical to upstream.
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/patchelf/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/patchelf/releases/download/<ver>/...
    xpm = {
        linux = {
            url_template = "https://github.com/NixOS/patchelf/releases/download/{version}/patchelf-{version}-x86_64.tar.gz",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    local patchelfdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(patchelfdir, pkginfo.install_dir())
    return true
end

function config()
    xvm.add("patchelf", { bindir = path.join(pkginfo.install_dir(), "bin") })
    xvm.add("elfpatch", { bindir = path.join(pkginfo.install_dir(), "bin"), alias = "patchelf" })
    return true
end

function uninstall()
    xvm.remove("patchelf")
    xvm.remove("elfpatch")
    return true
end
