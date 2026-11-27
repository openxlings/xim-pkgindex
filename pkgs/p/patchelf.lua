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

            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "13659e8da5c04d935bcee0c504c167d180d52fd535c11147c66a4b7c6316870f",
                    aarch64 = "a2ddd162d9a2f750b6eb735d205cbdcf311cb69ac6c45515b365f2bb72994f8c",
                },
            },
            ["0.19.3"] = {
                -- Upstream's static binaries under one top directory
                -- (tools/res/build.sh patchelf), the XLINGS_RES names.
                url = "XLINGS_RES",
                sha256 = {
                    x86_64  = "1bfa6d97c93d640415ea8efa381be465c48ec8ddb93e30db3dba310b05ebcdca",
                    aarch64 = "6b8b5bcf29b4b5eac67797f71620a05f0b44707a0323c5e8af6d416118ae2e37",
                },
            },
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
