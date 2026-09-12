-- esbuild -- the JavaScript/TypeScript bundler, as the single static binary
-- upstream ships.
--
-- WHY THIS PACKAGE EXISTS. A HuxerUI ecosystem library with a TypeScript
-- bridge (Lib-Live2D's `platform/web/bridge.ts`) bundles it into the page's
-- pre-JS with one esbuild invocation from its mcpp build program. The CMake
-- path reaches esbuild through `npm install --prefix .cache/web-tools
-- esbuild@0.25.12` at configure time -- a network step inside a build and a
-- node_modules tree beside the sources. An xlings payload is what lets the
-- build program name the tool and mcpp provision it, offline, once.
--
-- DISTRIBUTION: NPM ONLY, AND THE PLATFORM PACKAGES ARE THE BINARIES.
-- evanw/esbuild tags every release on GitHub but attaches no assets; the
-- binaries are published to npm as one package per platform
-- (`@esbuild/linux-x64`, `@esbuild/darwin-arm64`, ...), and the `esbuild`
-- package that `npm install esbuild` resolves is a JavaScript shim whose
-- `optionalDependencies` pull the matching platform package in. This
-- recipe fetches the platform package's tarball directly from
-- registry.npmjs.org and installs the binary it carries -- no node, no npm,
-- no shim. The tarball is what `npm pack @esbuild/<platform>@<ver>` would
-- produce: a gzipped tar whose sole top-level directory is `package/`.
--
-- The url is irregular across hosts and arches (npm's platform name, not
-- xlings'), so each entry is a per-arch `{ url, sha256 }` map
-- (docs/contributing.md ss2, "各架构 URL 不规则").
--
-- MEASURED (2026-09-13), each tarball fetched with curl from
-- https://registry.npmjs.org/@esbuild/<platform>/-/<platform>-0.25.12.tgz
-- and hashed; sizes are the download sizes:
--
--   npm platform    xlings host/arch    size      sha256 (below)
--   linux-x64       linux/x86_64        4395720   f7efc127...
--   linux-arm64     linux/aarch64       4042485   d5e01d21...
--   darwin-x64      macosx/x86_64       4469597   bf56cdf7...
--   darwin-arm64    macosx/aarch64      4191694   2e0d011f...
--   win32-x64       windows/x86_64      4484984   c77076b4...
--   win32-arm64     windows/aarch64     4079682   01979ffa...
--
-- ARCHIVE LAYOUT (measured with `tar tzf`): the POSIX packages carry
-- `package/bin/esbuild`, the win32 packages `package/esbuild.exe` at the
-- package root -- both beside `package/package.json` and `package/README.md`.
-- The install hook copies the one binary to `<install_dir>/bin/`, which is
-- the one layout `config()` registers.
--
-- LICENCE. MIT, upstream's LICENSE.md, carried in every platform package's
-- `package.json` (`"license": "MIT"`). Tier 1: redistributable, so a
-- xlings-res mirror is a follow-up publishing the release, not a fabricated
-- `CN` url -- the same omission android-build-tools.lua's header explains.
--
-- No `package.ci`: version-check.py reads GitHub release tags, which this
-- project has, but the assets it would verify live on npm. Bumps are read
-- off registry.npmjs.org/esbuild (`dist-tags.latest`) by hand, and every
-- platform package is published at the same version as the shim.

package = {
    spec = "2",

    name = "esbuild",
    description = "esbuild - an extremely fast bundler and minifier for JavaScript and TypeScript",
    homepage = "https://esbuild.github.io",
    maintainers = {"Evan Wallace"},
    licenses = {"MIT"},
    repo = "https://github.com/evanw/esbuild",
    docs = "https://esbuild.github.io/api/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "web", "javascript"},
    keywords = {"esbuild", "bundler", "minifier", "javascript", "typescript", "web", "wasm"},

    programs = {"esbuild"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.25.12" },
            ["0.25.12"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-0.25.12.tgz" },
                    sha256 = "f7efc127658a108dcda9d4210b01804ee8f5d6b3acbd6d63f20aa51d3b50bd5f",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/linux-arm64/-/linux-arm64-0.25.12.tgz" },
                    sha256 = "d5e01d210e026823d559e2b82554cdcdab6fd87c4a57b519b392ef183c1f87fd",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.25.12" },
            ["0.25.12"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/darwin-x64/-/darwin-x64-0.25.12.tgz" },
                    sha256 = "bf56cdf7b330a8605395ee13de805c784c7346d0802c7cced8490b4bfac2291a",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/darwin-arm64/-/darwin-arm64-0.25.12.tgz" },
                    sha256 = "2e0d011f852e45046ca5c107db54cfc56338f77aca49d227a063696d958451d7",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.25.12" },
            ["0.25.12"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/win32-x64/-/win32-x64-0.25.12.tgz" },
                    sha256 = "c77076b48f96323cae6257bd515e5ea96ecf38ab8f7fa34364d4fc4ae5905b74",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@esbuild/win32-arm64/-/win32-arm64-0.25.12.tgz" },
                    sha256 = "01979ffafb4bb6a63d824cd57ed76bd257d1e3eed804c3e47fdfd80005dcfa66",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function binary_name()
    return is_host("windows") and "esbuild.exe" or "esbuild"
end

function install()
    -- Idempotent across xim engines (mcpp#232, the nasm.lua idiom): some
    -- stage the extracted payload into install_dir() before the hook, others
    -- leave it in the hook CWD. Never report success unless the binary is in
    -- place -- `return true` over an empty dir is stamped as installed and
    -- leaves a dangling shim.
    local exe = binary_name()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local staged = path.join(bindir, exe)
    if os.isfile(staged) then return true end

    -- npm's tarball root is `package/`; see ARCHIVE LAYOUT above.
    local inside = is_host("windows") and exe or path.join("bin", exe)
    local candidates = {
        path.join("package", inside),
        path.join(pkginfo.install_dir(), "package", inside),
    }
    for _, src in ipairs(candidates) do
        if os.isfile(src) then
            os.mkdir(bindir)
            os.cp(src, staged)
            break
        end
    end
    -- The rest of the package (package.json, README.md) is not installed:
    -- the binary is the whole tool.
    os.tryrm(path.join(pkginfo.install_dir(), "package"))
    return os.isfile(staged)
end

function config()
    xvm.add("esbuild", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("esbuild")
    return true
end
