-- typescript -- the TypeScript compiler, `tsc`, as the native program
-- TypeScript 7 ships (the Go port): one static binary and the standard
-- library's declaration files beside it. No node, no npm.
--
-- WHY THIS PACKAGE EXISTS. omui's `omui check` type-checks an application's
-- TypeScript against the generated declarations with tsc (openmui's
-- TypeScript-first convergence, W1 step 5), in development and in CI. A
-- project names the tool in its mcpp.toml (`"xim:typescript"`) and mcpp
-- provisions it, offline, once -- the same way it names esbuild.
--
-- DISTRIBUTION: NPM ONLY, AND THE PLATFORM PACKAGES ARE THE BINARIES.
-- The `typescript` package of 7.x is a JavaScript shim whose
-- `optionalDependencies` pull one package per platform in
-- (`@typescript/typescript-linux-x64`, `...-darwin-arm64`, ...). Each carries
-- the native compiler. This recipe fetches the platform package's tarball
-- directly from registry.npmjs.org -- what `npm pack` would produce: a
-- gzipped tar whose sole top-level directory is `package/`.
--
-- The url is irregular across hosts and arches (npm's platform name, not
-- xlings'), so each entry is a per-arch `{ url, sha256 }` map
-- (docs/contributing.md ss2, "各架构 URL 不规则").
--
-- MEASURED (2026-11-09), each tarball fetched with curl from
-- https://registry.npmjs.org/@typescript/typescript-<platform>/-/typescript-<platform>-7.0.2.tgz,
-- hashed, and checked against the registry's `dist.integrity` (sha512);
-- sizes are the download sizes:
--
--   npm platform    xlings host/arch    size       sha256 (below)
--   linux-x64       linux/x86_64        9669334    7ecad6f6...
--   linux-arm64     linux/aarch64       8900516    c83d931a...
--   darwin-x64      macosx/x86_64       10057523   eba158cb...
--   darwin-arm64    macosx/aarch64      9270373    902e2fe1...
--   win32-x64       windows/x86_64      9776626    61fc4e14...
--   win32-arm64     windows/aarch64     8900840    0a73534e...
--
-- npm also publishes arm (32-bit), loong64, ppc64, riscv64, s390x,
-- mips64el, the BSDs, AIX and SunOS; the index has no arch or host key for
-- those yet, so they are not declared.
--
-- ARCHIVE LAYOUT (measured with `tar tzf`): `package/lib/tsc` (`tsc.exe` on
-- win32) beside the standard library's declarations `package/lib/lib.*.d.ts`
-- -- the compiler finds them next to itself, so the whole `lib/` directory is
-- installed as `<install_dir>/lib/`, which is the bindir `config()`
-- registers. Checked on linux-x64: `tsc --version` prints `Version 7.0.2`
-- and `tsc --noEmit` reports `a.ts(1,7): error TS2322: ...` for a wrong
-- type, exit 1.
--
-- LICENCE. Apache-2.0, upstream's LICENSE, carried in every platform
-- package (`"license": "Apache-2.0"` in its package.json). Redistributable,
-- so a xlings-res mirror is a follow-up publishing the release.
--
-- No `package.ci`: the assets live on npm. Bumps are read off
-- registry.npmjs.org/typescript (`dist-tags.latest`) by hand; every platform
-- package is published at the same version as the shim.

package = {
    spec = "2",

    name = "typescript",
    description = "TypeScript - the native TypeScript compiler (tsc 7)",
    homepage = "https://www.typescriptlang.org",
    maintainers = {"Microsoft"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/microsoft/typescript-go",
    docs = "https://www.typescriptlang.org/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "web", "javascript"},
    keywords = {"typescript", "tsc", "type-checker", "compiler", "javascript", "web"},

    programs = {"tsc"},
    xvm_enable = true,

    extensions = {

    },

    xpm = {
        linux = {
            ["latest"] = { ref = "7.0.2" },
            ["7.0.2"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-linux-x64/-/typescript-linux-x64-7.0.2.tgz" },
                    sha256 = "7ecad6f67377e831856367ab062ef394f21506a611405bf8ac0ff039348637d3",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-linux-arm64/-/typescript-linux-arm64-7.0.2.tgz" },
                    sha256 = "c83d931ac9dd7549cde6e71246aa9d6a9812843023df3e277fe3b5dcf41dd0ea",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "7.0.2" },
            ["7.0.2"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-darwin-x64/-/typescript-darwin-x64-7.0.2.tgz" },
                    sha256 = "eba158cb54050f723d5ff781438f33de5640054440bb4f2bd170cfe9bc2eb551",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-darwin-arm64/-/typescript-darwin-arm64-7.0.2.tgz" },
                    sha256 = "902e2fe1cf0799198ef902c6b8c310a450fef629a6baba41d45641ef75c04ebd",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "7.0.2" },
            ["7.0.2"] = {
                x86_64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-win32-x64/-/typescript-win32-x64-7.0.2.tgz" },
                    sha256 = "61fc4e141d2bc687db580e71bbfa63b9c209f0310645d82ca1b457eb3a24fd19",
                },
                aarch64 = {
                    url = { GLOBAL = "https://registry.npmjs.org/@typescript/typescript-win32-arm64/-/typescript-win32-arm64-7.0.2.tgz" },
                    sha256 = "0a73534e6ee50cdbb2a29ac48657ca0ad13cf0f424cf63808e4df7baeb87b8be",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function binary_name()
    return is_host("windows") and "tsc.exe" or "tsc"
end

function install()
    -- Idempotent across xim engines (mcpp#232, the nasm.lua idiom): some
    -- stage the extracted payload into install_dir() before the hook, others
    -- leave it in the hook CWD. Never report success unless the binary is in
    -- place -- `return true` over an empty dir is stamped as installed and
    -- leaves a dangling shim.
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local staged = path.join(libdir, binary_name())
    if os.isfile(staged) then return true end

    -- npm's tarball root is `package/`; see ARCHIVE LAYOUT above.
    local candidates = {
        path.join("package", "lib"),
        path.join(pkginfo.install_dir(), "package", "lib"),
    }
    for _, src in ipairs(candidates) do
        if os.isfile(path.join(src, binary_name())) then
            os.tryrm(libdir)
            os.cp(src, libdir)
            break
        end
    end
    os.tryrm(path.join(pkginfo.install_dir(), "package"))
    return os.isfile(staged)
end

function config()
    xvm.add("tsc", { bindir = path.join(pkginfo.install_dir(), "lib") })
    -- The program is `tsc`, the package `typescript`: a group placeholder
    -- under the package's name, as ripgrep.lua registers `ripgrep` beside
    -- `rg`, so install detection (`xvm info typescript`) and `xlings remove`
    -- find the package without a shim of that name.
    xvm.add("typescript", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("tsc")
    xvm.remove("typescript")
    return true
end
