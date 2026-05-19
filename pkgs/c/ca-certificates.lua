package = {
    spec = "1",

    name = "ca-certificates",
    description = "Mozilla CA root bundle (extracted by curl.se)",
    homepage = "https://curl.se/docs/caextract.html",
    licenses = {"MPL-2.0"},
    repo = "https://curl.se/docs/caextract.html",

    -- xim pkg info
    type = "package",
    -- pure PEM text, arch-independent — listing both for metadata honesty
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "tls", "system"},
    keywords = {"ca", "certificates", "tls", "ssl", "pem", "mozilla"},

    -- The bundle is a data-only payload (no executables), so this xpkg
    -- does not register any programs and intentionally omits xvm_enable.
    -- Versioning follows the curl.se publish date (YYYY.MM.DD).

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.03.19" },
            ["2026.03.19"] = {
                url = "https://curl.se/ca/cacert-2026-03-19.pem",
                sha256 = "b6e66569cc3d438dd5abe514d0df50005d570bfc96c14dca8f768d020cb96171",
            },
            ["2025.07.15"] = {
                url = "https://curl.se/ca/cacert-2025-07-15.pem",
                sha256 = "7430e90ee0cdca2d0f02b1ece46fbf255d5d0408111f009638e3b892d6ca089c",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

-- Resolve sysroot paths inside hooks so they pick up the active subos
-- (top-level evaluation may run before xlings sets the sysroot).
local function _sys_etc_certs_dir()
    return path.join(system.subos_sysrootdir(), "etc", "ssl", "certs")
end
local function _sys_etc_ssl_dir()
    return path.join(system.subos_sysrootdir(), "etc", "ssl")
end

-- Canonical filenames used by common toolchains:
--   <etc>/ssl/certs/ca-certificates.crt   — Debian/Ubuntu, OpenSSL default
--   <etc>/ssl/cert.pem                    — FreeBSD / macOS / curl default
local _CANONICAL_BUNDLE = "ca-certificates.crt"
local _CANONICAL_LINK   = "cert.pem"

function install()
    -- The download is a single .pem file (not an archive), so xlings's
    -- auto-stage doesn't run; the PEM still lands in the runtime download
    -- dir and we move it explicitly into a fresh install_dir as `cacert.pem`.
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    os.cp(pkginfo.install_file(),
          path.join(pkginfo.install_dir(), "cacert.pem"),
          { force = true })
    return os.isfile(path.join(pkginfo.install_dir(), "cacert.pem"))
end

function config()
    xvm.add(package.name)

    local certs_dir = _sys_etc_certs_dir()
    local ssl_dir   = _sys_etc_ssl_dir()
    local pem_src   = path.join(pkginfo.install_dir(), "cacert.pem")
    local pem_dst   = path.join(certs_dir, _CANONICAL_BUNDLE)
    local pem_link  = path.join(ssl_dir, _CANONICAL_LINK)

    log.info("installing CA bundle to subos sysroot...")
    os.mkdir(certs_dir)

    -- Use shell cp via system.exec so behavior is consistent with how
    -- other xpkgs stage files into the sysroot (the xpkg sandbox's
    -- builtin os.cp dest-as-dir semantics is unreliable for some hosts).
    system.exec(string.format("cp -f %s %s", pem_src, pem_dst))

    -- Drop a `cert.pem` alias next to it for tools (curl, FreeBSD-style
    -- toolchains) that look there. Use a relative symlink so the link
    -- stays valid even if the sysroot is later relocated.
    os.tryrm(pem_link)
    system.exec(string.format("ln -sf certs/%s %s",
        _CANONICAL_BUNDLE, pem_link))

    log.info("CA bundle installed: %s", pem_dst)
    log.info("CA bundle alias:     %s -> certs/%s", pem_link, _CANONICAL_BUNDLE)
    return true
end

function uninstall()
    os.tryrm(path.join(_sys_etc_certs_dir(), _CANONICAL_BUNDLE))
    os.tryrm(path.join(_sys_etc_ssl_dir(), _CANONICAL_LINK))
    return true
end
