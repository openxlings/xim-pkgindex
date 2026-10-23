-- XPackage V2 template: copy to pkgs/<first letter>/<name>.lua.
-- Rules: docs/specs/xpackage-v2.md. Path: docs/10-adding-a-package.md.
package = {
    spec = "2",

    name = "package-name",
    description = "One sentence on what it is",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/acme/package-name",

    -- checked against the host, fail-closed: claim only what was tested
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"program1"},
    xvm_enable = true,

    -- data for another program, keyed by its registered namespace; xlings
    -- hands it on and never reads it (docs/specs/xpackage-v2.md "extensions")
    -- extensions = { luban = { title = { en = "Package Name" } } },

    -- Optional automatic updates (docs/13-ci-mirror-and-update.md).
    -- Recommended for upstream GitHub repositories with >= 50 stars; not enforced.
    -- Official Sparkle feeds can use source = "https://vendor.example/appcast.xml"
    -- with fixed ${version} templates instead; no GitHub/tag declaration is needed.
    -- Every required platform must publish the same version before latest advances.
    -- Uncomment after verifying URLs and the complete supported platform/arch matrix.
    -- Merge this into an existing extensions table rather than adding a second one.
    -- extensions = {
    --     autoupdate = {
    --         source = "https://github.com/acme/package-name/releases",
    --         resources = {
    --             GLOBAL = { url = {
    --                 linux = {
    --                     x86_64 = "https://github.com/acme/package-name/releases/download/${tag}/package-name-linux-amd64.tar.gz",
    --                     aarch64 = "https://github.com/acme/package-name/releases/download/${tag}/package-name-linux-arm64.tar.gz",
    --                 },
    --                 macosx = {
    --                     x86_64 = "https://github.com/acme/package-name/releases/download/${tag}/package-name-macos-x64.tar.gz",
    --                     aarch64 = "https://github.com/acme/package-name/releases/download/${tag}/package-name-macos-arm64.tar.gz",
    --                 },
    --             } },
    --         },
    --     },
    -- },
    -- latest = "advance" and required = true are defaults. No verified mirror: GLOBAL only.
    -- Add CN only with verified matching assets; required = false makes it optional.
    -- Run inspect/check before opening the PR; CI generates the coverage artifact.

    xpm = {
        -- the default source: "xlings-res" for official resources, or a template
        -- with ${name} ${version} ${os} ${arch} ${arch_alias} ${ext}
        source = "https://github.com/acme/package-name/releases/download/v${version}/${name}-${os}-${arch_alias}.${ext}",
        linux = {
            -- deps = { runtime = { "xim:glibc" }, build = { "xim:7zip" } },
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = { x86_64 = "<amd64-sha256>", aarch64 = "<arm64-sha256>" },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.0.0" },
            -- irregular URLs: one resource per architecture
            ["1.0.0"] = {
                x86_64  = { url = "https://example.com/package-name-1.0.0-macos-x64.tar.gz", sha256 = "<sha256>" },
                aarch64 = { url = "https://example.com/package-name-1.0.0-macos-arm64.tar.gz", sha256 = "<sha256>" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(pkginfo.install_file():replace(".tar.gz", ""), pkginfo.install_dir())
    return true
end

function config()
    xvm.add("program1", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("program1")
    return true
end
