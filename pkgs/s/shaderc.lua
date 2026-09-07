package = {
    spec = "2",

    homepage = "https://github.com/google/shaderc",
    name = "shaderc",
    description = "shaderc: glslc, the GLSL/HLSL to SPIR-V compiler, and the SPIRV-Tools binaries",

    authors = {"The Shaderc Authors", "The Khronos Group Inc."},
    -- The set, not the headline. This payload is a closure of three upstream
    -- packages: shaderc itself (Apache-2.0), the glslang front end it links
    -- (a BSD-3-Clause and Apache-2.0 collection, plus the MIT-licensed
    -- SPIRV-Headers it embeds) and SPIRV-Tools (Apache-2.0). `licenses/`
    -- inside the payload carries the texts and `PROVENANCE.md` says which
    -- upstream package contributed which.
    licenses = {"Apache-2.0", "BSD-3-Clause", "MIT"},
    repo = "https://github.com/google/shaderc",
    docs = "https://github.com/google/shaderc/blob/main/glslc/README.asciidoc",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "compiler", "spirv"},
    keywords = {"glslc", "shaderc", "spirv", "glsl", "hlsl", "vulkan"},

    programs = {"glslc", "spirv-as", "spirv-dis", "spirv-link", "spirv-opt", "spirv-val"},
    xvm_enable = true,

    -- WHAT THIS PACKAGE IS FOR, AND WHY IT IS NOT xim:glslang.
    --
    -- Two reference GLSL compilers exist and they are not interchangeable at
    -- the command line. glslang's `-x --vn` emits a complete C declaration;
    -- glslc's `-mfmt=c` emits a bare initialiser list. A project that drives
    -- one cannot be handed the other, and the projects that matter here drive
    -- glslc by name -- llama.cpp's `vulkan-shaders-gen` takes a
    -- `GLSLC_EXECUTABLE` and passes glslc's flags to it.
    --
    -- Until this package, `mcpp.rules.spirv` stated in its own source that the
    -- glslc route was unsupported "because nothing in this ecosystem publishes
    -- it, and a route with no payload behind it is a claim rather than a
    -- feature". This is that payload; the claim becomes a route.
    --
    -- WHY A REPACK AND NOT A BUILD. shaderc's build vendors glslang and
    -- SPIRV-Tools at exact revisions through its own `DEPS` file and expects
    -- to compile all three together. conda-forge already resolves that
    -- pairing per release and builds against a glibc 2.17 baseline, for both
    -- architectures this index publishes.
    --
    -- WHAT IS AND IS NOT REGISTERED. The payload contains a glslang 16.5.0 --
    -- newer than `xim:glslang`, which publishes 15.1.0 -- and its
    -- `bin/glslang` and `bin/glslangValidator` are removed rather than
    -- registered: two packages competing for one program name is a race whose
    -- winner is whichever installed last, and a project that wants glslang
    -- asks for glslang. The libraries stay private to the payload for the
    -- same reason and are not declared into the subos library view.
    xpm = {
        linux = {
            -- `bin/glslc` needs libstdc++/libgcc_s and libc; everything else
            -- it needs is inside this payload and reached through
            -- DT_RPATH=$ORIGIN/../lib, written when the payload was
            -- assembled and reapplied by selfcontain.seal below.
            deps = { "xim:glibc", "xim:gcc-runtime@>=15" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2026.3" },
            ["2026.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "73eff75ed532b072daa30e206fc5873b19bc96659a3a2517c1e5b50119707a94",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "15505e0018d9624ac71461464103aafcca9d11c0a125af00af2caf340d290c2a",
                },
            },
        },

        -- ALSO conda-forge, and for a measured reason rather than symmetry:
        -- Google's own macOS drop is `Mach-O 64-bit x86_64` and stamps
        -- `shaderc v2026.2`, while this ecosystem's macOS is arm64 and the
        -- version published here is 2026.3.
        --
        -- Nothing is resealed. Every executable carries
        -- `@loader_path/../lib/` and every library `@loader_path/`, so the
        -- payload is relocatable as it stands; `libc++.1.dylib` is bundled
        -- because the binaries reference it as `@rpath/libc++.1.dylib` and
        -- `@rpath` resolves only through the load commands -- the system copy
        -- in `/usr/lib` is never reached.
        macosx = {
            ["latest"] = { ref = "2026.3" },
            ["2026.3"] = {
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-macosx-arm64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-macosx-arm64.tar.gz",
                    },
                    sha256 = "1337e812b46f1068d26053f61c979a702a4ebb2195d61586a3abfbc01721b822",
                },
            },
        },

        -- NOT conda-forge here, and the reason is the dependency it would
        -- bring. conda-forge's `win-64` `glslc.exe` imports `MSVCP140.dll` and
        -- `VCRUNTIME140_1.dll` and loads `shaderc.dll` and `SPIRV-Tools.dll`
        -- beside it, so it needs the Visual C++ redistributable installed on
        -- the machine. Google's own Windows build imports `KERNEL32.dll` and
        -- nothing else: static CRT, no side libraries. A build tool that
        -- depends on something the ecosystem did not install is the dependency
        -- this index exists to remove, so the self-contained build is packaged.
        --
        -- There is no `lib/` and nothing to seal: the six programs are
        -- standalone.
        windows = {
            ["latest"] = { ref = "2026.3" },
            ["2026.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-windows-x86_64.zip",
                        CN     = "https://gitcode.com/xlings-res/shaderc/releases/download/2026.3/shaderc-2026.3-windows-x86_64.zip",
                    },
                    sha256 = "3f66d53b56cd2653e246e73cd2c68b757e19c1db2192ac974bead4f6ab2aa03a",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.pkgindex.selfcontain")

local programs = {"glslc", "spirv-as", "spirv-dis", "spirv-link", "spirv-opt", "spirv-val"}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- The tarball's top-level directory carries the version. Moving a name
    -- that is not there leaves the download directory as the payload while
    -- install() still reports success -- a package that installs cleanly and
    -- has no bin/.
    local top = "shaderc-" .. pkginfo.version()
    if not os.isdir(top) then
        log.error("shaderc: expected %s in the extracted archive", top)
        return false
    end
    os.mv(top, dir)

    local exe = is_host("windows") and ".exe" or ""
    if not os.isfile(path.join(dir, "bin/glslc" .. exe)) then
        log.error("shaderc: payload is incomplete after the move; no bin/glslc%s", exe)
        return false
    end

    -- This payload's own dependency closure (glibc, gcc-runtime), stamped
    -- onto both halves: the default libdirs list is {"lib","lib64"}, which
    -- would leave bin/ untouched and glslc's libstdc++ resolving from the
    -- host.
    --
    -- The recipe does not choose the dynamic tag and must not. elfpatch
    -- stamps DT_RPATH on an object with a PT_INTERP and DT_RUNPATH on one
    -- without, because RPATH is consulted for every dlopen beneath it while
    -- RUNPATH is consulted only for its own object -- and forcing RPATH onto
    -- a library was measured harmful (xim-pkgindex#593). So bin/ comes out
    -- DT_RPATH and lib/ DT_RUNPATH, which is the correct split here: the
    -- programs are what a caller's search path has to reach through.
    -- ELF ONLY. `selfcontain.seal` writes DT_RPATH/DT_RUNPATH through elfpatch,
    -- and neither of the other two platforms has that problem to solve: the
    -- macOS payload is already relocatable through `@loader_path`, and the
    -- Windows programs carry no side libraries at all.
    if is_host("linux") then
        selfcontain.seal(dir, { "lib", "bin" })
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = path.join(dir, "bin")
    local binding = package.name .. "@" .. pkginfo.version()

    -- The anchor entry is named after the package; a node cannot bind to
    -- itself, so the programs bind to it rather than the other way round.
    local exe = is_host("windows") and ".exe" or ""
    xvm.add(package.name)
    for _, prog in ipairs(programs) do
        if os.isfile(path.join(bindir, prog .. exe)) then
            xvm.add(prog, { bindir = bindir, alias = prog, binding = binding })
        end
    end
    return true
end

function uninstall()
    for _, prog in ipairs(programs) do
        xvm.remove(prog)
    end
    os.tryrm(pkginfo.install_dir())
    return true
end
