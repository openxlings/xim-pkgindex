package = {
    spec = "2",
    homepage = "https://shader-slang.org",

    name = "slang",
    description = "Slang shading language compiler — HLSL-like source to SPIR-V / DXIL / Metal / WGSL",

    maintainers = {"https://github.com/shader-slang/slang/graphs/contributors"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/shader-slang/slang",
    docs = "https://shader-slang.org/slang/user-guide/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "shader", "compiler"},
    keywords = {"slang", "slangc", "shader", "spirv", "hlsl", "vulkan", "dxil", "metal", "wgsl"},

    -- slangc  — the shader compiler (the reason most people install this)
    -- slangd  — the language server (editor integration)
    -- slangi  — the interpreter
    -- slang   — the reflection/introspection driver
    programs = {"slangc", "slangd", "slangi", "slang"},
    xvm_enable = true,

    -- Upstream ships prebuilt archives for every platform/arch pair under a
    -- regular naming scheme, so one template per platform covers everything.
    -- Two irregularities are handled by platform-scope `source` overrides
    -- rather than by an `arch_alias`:
    --   * the release TAG carries a `v` prefix (`v2026.14.1`) while the FILE
    --     name does not (`slang-2026.14.1-...`);
    --   * xlings spells macOS `macosx`, upstream spells it `macos`.
    -- `${ext}` already resolves to `zip` on windows and `tar.gz` elsewhere,
    -- which matches upstream exactly.
    xpm = {
        linux = {
            -- The Linux archives are dynamically linked against glibc and
            -- libstdc++: `bin/slangc` carries DT_NEEDED on libm/libdl/libpthread
            -- /libc (glibc) and libstdc++/libgcc_s (gcc-runtime). Declaring
            -- glibc is also what moves PT_INTERP into the xlings sandbox, and
            -- once the interpreter moves there is no host fallback — so
            -- gcc-runtime is not an optional extra, it is the rest of the
            -- closure.
            deps = { "xim:glibc@>=2.38", "xim:gcc-runtime@>=13" },
            source = "https://github.com/shader-slang/slang/releases/download/v${version}/slang-${version}-linux-${arch}.${ext}",
            ["latest"] = { ref = "2026.14.1" },
            ["2026.14.1"] = {
                sha256 = {
                    x86_64  = "21f2d7847385a770e569fb61b1507a7794d742d97850bce0432bff0032ca005f",
                    aarch64 = "438325c6529ba658f571614d9d551cdff09e730836d29c26c290afc8ed996985",
                },
            },
        },
        macosx = {
            source = "https://github.com/shader-slang/slang/releases/download/v${version}/slang-${version}-macos-${arch}.${ext}",
            ["latest"] = { ref = "2026.14.1" },
            ["2026.14.1"] = {
                sha256 = {
                    aarch64 = "92da7ab6226dd951037cd85397f830ae78fe40fbbb8928882e0b2654e468fdd4",
                    x86_64  = "adc5e179f5584ca572293e93612df9f0b6be8a46dcb53622238efc7a62b1da2f",
                },
            },
        },
        windows = {
            source = "https://github.com/shader-slang/slang/releases/download/v${version}/slang-${version}-windows-${arch}.${ext}",
            ["latest"] = { ref = "2026.14.1" },
            ["2026.14.1"] = {
                sha256 = {
                    x86_64  = "5ed0a59d650a0af0aca45d5db4e083b3d8fb5cea05748747dd95dfbe9c580658",
                    aarch64 = "5067047bb35ae5675b06a3467d0b302d9816727450a803cb3770660bef684f37",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The upstream archive extracts FLAT — `bin/`, `include/`, `lib/`, `share/`,
-- `docs/`, `LICENSE` at top level with no `slang-<ver>-<os>-<arch>/` wrapper —
-- so the stock `os.mv(<archive-basename>, install_dir)` idiom finds nothing.
--
-- Rather than mirroring a repackaged tarball (patchelf.lua's route), the payload
-- root is located BY CONTENT: `bin/slangc*` is the marker. That covers both
-- shapes without guessing, so if upstream ever adds a top-level directory this
-- recipe keeps working unchanged.
local function payload_root()
    local named = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    if os.isdir(named) then
        return named
    end

    -- Flat archive: the contents landed beside the downloaded file.
    local base = path.directory(pkginfo.install_file())
    local exe  = is_host("windows") and "slangc.exe" or "slangc"
    if os.isfile(path.join(base, "bin", exe)) then
        return base
    end

    -- Defensive: the extraction directory can be shared, so also look one level
    -- down for whichever sibling actually carries bin/slangc.
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "bin", exe)) then
            return d
        end
    end

    raise("cannot find the slang payload under '" .. base
          .. "': no directory contains bin/" .. exe)
end

function install()
    local src = payload_root()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    if src == path.directory(pkginfo.install_file()) then
        -- Flat: move the known payload entries rather than the whole extraction
        -- directory, which also holds the archive itself (and possibly other
        -- packages' files).
        -- os.exists / os.files / os.filedirs are NOT available in the recipe
        -- sandbox (see spirv-tools.lua, which hit the same wall); os.isdir and
        -- os.isfile are.
        os.mkdir(dir)
        for _, name in ipairs({"bin", "include", "lib", "share", "docs",
                               "LICENSE", "LICENSES", "README.md"}) do
            local p = path.join(src, name)
            if os.isdir(p) or os.isfile(p) then
                os.mv(p, path.join(dir, name))
            end
        end
    else
        os.mv(src, dir)
    end

    -- Assert the payload is what the `programs` list promises. A silently
    -- half-extracted archive would otherwise register shims for binaries that
    -- do not exist, and the failure would surface much later as "command not
    -- found" with no hint about which package is at fault.
    local exe = is_host("windows") and ".exe" or ""
    for _, prog in ipairs({"slangc", "slangd"}) do
        if not os.isfile(path.join(dir, "bin", prog .. exe)) then
            raise("slang payload is missing bin/" .. prog .. exe)
        end
    end

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add("slangc", { bindir = bindir })
    xvm.add("slangd", { bindir = bindir })
    xvm.add("slangi", { bindir = bindir })
    xvm.add("slang",  { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("slangc")
    xvm.remove("slangd")
    xvm.remove("slangi")
    xvm.remove("slang")
    return true
end
