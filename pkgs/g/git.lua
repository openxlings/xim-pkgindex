package = {
    spec = "1",

    name = "git",
    description = "Git is a free and open source distributed version control system",

    homepage = "https://git-scm.com",
    maintainers = {"GNU"},
    licenses = {"GPL"},

    repo = "https://github.com/git/git",
    docs = "https://git-scm.com/learn",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"git"},
    keywords = {"git"},

    programs = { "git" },

    xpm = {
        windows = {
            deps = { "shortcut-tool" },
            ["latest"] = { ref = "2.51.1" },
            ["2.51.1"] = "XLINGS_RES",
        },
        linux = {
            -- TODO(self-build): migrate to xlings-res official mirror.
            -- Currently sourced from the community project
            -- supriyo-biswas/static-builds, which ships a fully
            -- statically-linked git tarball (verified via readelf:
            -- empty DT_NEEDED, no .interp section). Pros: zero deps,
            -- single download, currently tracks upstream within days
            -- (git-2.53.0 published 2026-03-19). Cons: single
            -- maintainer, no SLA, build environment opaque.
            --
            -- Plan: once the xim-pkgindex-build self-build pipeline
            -- (alpine + musl, similar to scode:gcc → xlings-res/gcc
            -- chain) is in place, switch this to:
            --   url = ...xlings-res/git/<ver>/git-<ver>-linux-x86_64.tar.gz
            -- so xim owns the build chain end-to-end and removes the
            -- community-source dependency. Same migration applies to
            -- xim:vim (currently dtschan/vim-static, 2019 stale) and
            -- any future T2 pkgs.
            ["latest"] = { ref = "2.53.0" },
            ["2.53.0"] = {
                url = "https://github.com/supriyo-biswas/static-builds/releases/download/git-2.53.0/git-2.53.0-linux-x86_64.tar.gz",
                sha256 = "948a9bb92e74e9a5e5bdd6d8a19e49712f46d9709ddcda924bf17828a794d297",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

function install()
    if is_host("windows") then
        -- Windows: PortableGit zip extracts to a `PortableGit/` sibling
        -- dir; old recipe relied on the file-name prefix matching.
        os.tryrm(pkginfo.install_dir())
        local git_dir = pkginfo.install_file():replace(".zip", "")
        os.mv(git_dir, pkginfo.install_dir())
    else
        -- Linux: static-builds tarball has `bin/`, `libexec/`, `share/`
        -- at its top level (no enclosing version-named subdir, despite
        -- the tarball filename). Extract directly into install_dir so
        -- git can find libexec/git-core helpers via its argv[0]-relative
        -- resolution. Use explicit `tar -xzf -C` (same shape as
        -- ollama.lua) rather than relying on xlings's implicit
        -- pre-extract behavior, which can leak runtimedir state into
        -- this package's install_dir on shared-cache hosts.
        os.tryrm(pkginfo.install_dir())
        os.mkdir(pkginfo.install_dir())
        system.exec(string.format(
            [[tar -xzf "%s" -C "%s"]],
            pkginfo.install_file(), pkginfo.install_dir()
        ))
    end
    return true
end

-- Returns the host's CA bundle when the binary's compiled-in default
-- (/etc/ssl/cert.pem) is missing, else nil (default is already correct).
function find_ca_bundle()
    if os.isfile("/etc/ssl/cert.pem") then
        return nil
    end
    local candidates = {
        "/etc/ssl/certs/ca-certificates.crt",              -- Debian/Ubuntu, Arch, openSUSE
        "/etc/pki/tls/certs/ca-bundle.crt",                -- RHEL/CentOS/Fedora
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", -- Fedora (ca-trust)
        "/etc/ssl/ca-bundle.pem",                          -- older openSUSE
    }
    for _, f in ipairs(candidates) do
        if os.isfile(f) then
            return f
        end
    end
    return nil
end

function config()
    if is_host("windows") then
        xvm.add("git", {
            bindir = path.join(pkginfo.install_dir(), "cmd")
        })

        system.exec(string.format(
            [[shortcut-tool create --name "Git Bash" --target "%s" --icon "%s" --args "%s"]],
            path.join(pkginfo.install_dir(), "git-bash.exe"),
            path.join(pkginfo.install_dir(), "git-bash.exe"),
            "--cd-to-home"
        ))
    else
        local config = {
            bindir = path.join(pkginfo.install_dir(), "bin")
        }

        -- CA bundle: the static-builds tarball links OpenSSL with
        -- OPENSSLDIR=/etc/ssl, so its default cert FILE is /etc/ssl/cert.pem
        -- (the BSD/Alpine layout). Debian/Ubuntu/RHEL ship the bundle
        -- elsewhere and never create that file, so every HTTPS transport
        -- dies with:
        --   fatal: unable to access '...': error adding trust anchors
        --   from file: /etc/ssl/cert.pem
        -- The string lives in libexec/git-core/git-remote-https (the helper
        -- that actually runs curl), not in bin/git.
        --
        -- Only GIT_SSL_CAINFO fixes it: git passes CURLOPT_CAINFO from its
        -- compiled-in default, which overrides SSL_CERT_FILE (OpenSSL-level)
        -- and CURL_CA_BUNDLE (curl-level); GIT_SSL_CAPATH does not help
        -- either, because curl fails on the missing CAINFO before it would
        -- consult a CApath.
        --
        -- Left untouched when /etc/ssl/cert.pem exists (Alpine/BSD, and any
        -- host that symlinked it): there the built-in default is correct.
        local ca_bundle = find_ca_bundle()
        if ca_bundle then
            config.envs = { GIT_SSL_CAINFO = ca_bundle }
            log.info("git: pinning GIT_SSL_CAINFO to " .. ca_bundle
                     .. " (/etc/ssl/cert.pem absent)")
        end

        xvm.add("git", config)
    end

    return true
end

function uninstall()
    xvm.remove("git")
    if is_host("windows") then
        system.exec(string.format(
            [[shortcut-tool remove --name "Git Bash"]]
        ))
    end
    return true
end