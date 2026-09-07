-- dpcpp — Intel's LLVM-based SYCL compiler (`intel/llvm`).
--
-- WHY THIS IS AN LLVM PACKAGE AND NOT A NEW COMPILER FAMILY
--
-- `intel/llvm` describes itself as the "Home for Intel LLVM-based projects";
-- icpx is clang with a SYCL front end. Its driver, its flags and its module
-- support are clang's. Nothing that consumes it needs to learn a second
-- compiler shape.
--
-- WHAT THE LINUX RELEASE CONTAINS, MEASURED RATHER THAN ASSUMED
--
-- The v7.1.0 Linux build is configured with `--cuda --hip`, and its release
-- notes list "NVIDIA CUDA BACKEND on NVIDIA GeForce RTX 3090" among the tested
-- configurations. Verified on this index's side: `sycl-ls` from this payload
-- reports `[cuda:gpu] NVIDIA CUDA BACKEND` on a host with an NVIDIA driver.
-- So the Linux asset needs no rebuild to reach NVIDIA or AMD devices.
--
-- WHAT THE WINDOWS RELEASE CONTAINS, AND WHAT IT DOES NOT
--
-- `sycl_windows.tar.gz` is published for the same tag and the same version,
-- and it is a complete toolchain: `bin/clang++.exe`, `bin/sycl-ls.exe`,
-- `lib/sycl.lib` and `bin/sycl9.dll`. It is taken as published; nothing here
-- repacks it.
--
-- The release notes state that "HIP & CUDA plugins on Windows are not being
-- built", and the asset agrees: the adapters it carries are
-- `ur_adapter_level_zero*.dll` and `ur_adapter_opencl*.dll`, with no CUDA and
-- no HIP among them. So the Windows lane reaches Intel GPUs through Level
-- Zero and any OpenCL device, and reaches NVIDIA and AMD devices only on
-- Linux. That asymmetry belongs to the upstream release, not to this recipe,
-- and is recorded rather than papered over: a Windows entry built from source
-- with `--cuda --hip` would carry the same version number as an asset with
-- different device coverage, which is worse than the gap.
--
-- WHAT IT CARRIES THAT THE SLIM LLVM PAYLOAD DOES NOT
--
-- `clang-linker-wrapper`, `clang-offload-bundler` and `llvm-offload-binary`.
-- `xim:llvm` is a slim build (36 binaries) without them, so `-fgpu-rdc`
-- fails there with `llvm-offload-binary command failed`. Consumers that need
-- separate device compilation can use this payload's clang for it.
package = {
    spec = "1",

    name = "dpcpp",
    description = "Intel oneAPI DPC++/SYCL compiler (LLVM-based), with CUDA and HIP backends",

    maintainers = {"Intel"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/intel/llvm",
    docs = "https://intel.github.io/llvm-docs",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compiler", "gpu", "sycl", "oneapi"},
    keywords = {"sycl", "dpcpp", "icpx", "oneapi", "llvm", "gpu", "cuda", "hip"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- patchelf, to force DT_RPATH rather than DT_RUNPATH on the
            -- programs. A BUILD dep so the install order is deterministic
            -- instead of trusting patchelf to be on the shim PATH already --
            -- the reason godot.lua and libglvnd.lua declare it the same way.
            build = { "xim:patchelf@0.18.0" },
            source = "https://github.com/intel/llvm/releases/download/v${version}/sycl_linux.tar.gz",
            ["latest"] = { ref = "7.1.0" },
            ["7.1.0"] = {
                sha256 = {
                    x86_64 = "992de12d5c68ba8fd630446b1a97487361b38807b33140769e4c818795f0fcab",
                },
            },
        },

        -- No `build` dep here. patchelf is an ELF tool and the search-path
        -- rewrite it performs below has no Windows counterpart: the PE loader
        -- looks beside the executable, which is where this payload's DLLs are.
        windows = {
            source = "https://github.com/intel/llvm/releases/download/v${version}/sycl_windows.tar.gz",
            ["latest"] = { ref = "7.1.0" },
            ["7.1.0"] = {
                sha256 = {
                    x86_64 = "8337faf4e1cdfb7a66e383927e19803b89d3241566bffa9b2feace761d539544",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- ⚠️⚠️ THE ARCHIVE IS FLAT, AND xim UNPACKS IN PLACE INTO A SHARED DIRECTORY.
--
-- `sycl_linux.tar.gz` has `./bin`, `./lib` and `./include` at the top with no
-- wrapping directory. xim extracts an archive beside itself, and that place is
-- `~/.xlings/data/runtimedir` -- shared with every other package's download.
--
-- So this recipe must NOT move "the directory the archive unpacked to": that
-- directory is the shared one, and moving it would take other packages'
-- downloads with it. It moves the three entries this archive is known to
-- contain, by name.
--
-- ⭐ AND THE ASSERTIONS COME FIRST. The source directory is shared, so a
-- `bin/` found there is not necessarily ours; a completeness check placed
-- after the move would already have moved someone else's tree. This is the
-- same shape `cc-connect` documents, and it was learned the same way -- an
-- earlier revision of this recipe extracted 815 files into the shared
-- directory before the check ran.
local ENTRIES = { "bin", "lib", "include" }

-- THE COMPLETENESS CHECK NAMES FILES, SO IT IS PER-PLATFORM.
--
-- The two assets carry the same toolchain under different file names: the
-- driver is `clang++` or `clang++.exe`, and the SYCL runtime is `libsycl.so`
-- (linked against directly) or the pair `lib/sycl.lib` + `bin/sycl9.dll`. A
-- check written for one spelling passes vacuously on the other only if it is
-- allowed to be absent, so the list is chosen by host and both branches are
-- required.
--
-- `sycl.lib` rather than `sycl9.lib`: the digit is the SYCL ABI major and
-- moves with the release, while the unsuffixed import library does not.
local function required_files()
    if is_host("windows") then
        return { path.join("bin", "clang++.exe"),
                 path.join("bin", "sycl-ls.exe"),
                 path.join("lib", "sycl.lib") }
    end
    return { path.join("bin", "clang++"),
             path.join("bin", "sycl-ls"),
             path.join("lib", "libsycl.so") }
end

-- ELF ONLY. The Windows asset needs none of this: the PE loader searches
-- the directory holding the executable, and this payload's DLLs are in
-- `bin/` beside the programs that load them.
local function patch_program_rpaths(dir)
    -- FIVE OF THIS PAYLOAD'S PROGRAMS SHIP WITH NO SEARCH PATH AT ALL.
    --
    -- `clang++` and the driver binaries carry RUNPATH=$ORIGIN/../lib from the
    -- upstream build. `sycl-ls`, `sycl-prof`, `sycl-trace`, `sycl-sanitize`
    -- and `syclbin-dump` carry neither RPATH nor RUNPATH, so once the payload
    -- is anywhere other than its build prefix they cannot find a library in
    -- their own directory:
    --
    --   sycl-ls: error while loading shared libraries: libsycl.so.9: cannot
    --   open shared object file: No such file or directory
    --
    -- and those five are exactly the programs whose job is to report which
    -- devices this payload can reach. The `[cuda:gpu] NVIDIA CUDA BACKEND`
    -- recorded in the comment at the top of this file was measured with
    -- LD_LIBRARY_PATH set, which is why an installed payload nobody could run
    -- still read as working.
    --
    -- DT_RPATH ON THE PROGRAMS, AND NOTHING ON THE LIBRARIES. Both halves of
    -- that sentence were arrived at by measuring the alternative.
    --
    -- DT_RUNPATH is honoured for an object's own DT_NEEDED and NOT for a
    -- dlopen made beneath it; DT_RPATH is searched for both, at any depth.
    -- This payload's device support is a chain of dlopens -- `sycl-ls` loads
    -- `libsycl.so.9`, which loads `libur_loader.so.0`, which loads one
    -- `libur_adapter_*.so.0` per back end, and those need `libumf.so.1` from
    -- this same directory -- so only the transitive tag reaches the bottom.
    -- With RUNPATH the programs start and then report no platforms at all,
    -- every adapter failing on `libumf.so.1`.
    --
    -- Giving the LIBRARIES a search path of their own answers that too, and it
    -- is the wrong answer. A non-empty RUNPATH on a payload library switches
    -- OFF the inherited DT_RPATH of whatever loaded it, so an mcpp artifact
    -- that reaches this payload through a runtime adapter stops seeing its own
    -- farm: measured, `libur_adapter_cuda.so.0` then failed on `libcuda.so.1`
    -- and then on `libnvidia-ml.so.1`, each of which the artifact's own path
    -- had been supplying. Every consumer would have to re-farm this payload's
    -- entire external closure. The libraries are therefore left exactly as
    -- upstream shipped them, and only the programs are patched.
    --
    -- `selfcontain.seal` is not used for the same class of reason: it sets the
    -- INTERPRETER as well, and behind the ecosystem's private loader there is
    -- no host fallback -- CI's dependency-closure check refuses this payload
    -- there, naming `libOpenCL.so.1`, `libcupti.so.12`, `libnvidia-ml.so.1`
    -- and `libz.so.1`, for which this index publishes no provider. Closing the
    -- payload properly is a packaging round of its own and is recorded here
    -- rather than half-done.
    local pe = "patchelf"
    if pkginfo.build_dep then
        local ok, bd = pcall(function() return pkginfo.build_dep("xim:patchelf") end)
        if not (ok and bd and bd.bin) then
            ok, bd = pcall(function() return pkginfo.build_dep("patchelf") end)
        end
        if ok and bd and bd.bin and os.isfile(path.join(bd.bin, "patchelf")) then
            pe = path.join(bd.bin, "patchelf")
        end
    end
    -- SINGLE quotes around the rpath: `$ORIGIN` must reach patchelf literally,
    -- and os.exec goes through a shell.
    local patched, skipped = 0, {}
    for _, prog in ipairs({ "sycl-ls", "sycl-prof", "sycl-trace", "sycl-sanitize",
                            "syclbin-dump" }) do
        local exe = path.join(dir, "bin", prog)
        if os.isfile(exe) then
            os.exec(string.format([[%s --force-rpath --set-rpath '$ORIGIN/../lib' "%s"]], pe, exe))
            -- ASSERT THE ARTIFACT, NOT THE INTENT. patchelf may be absent, and
            -- a skipped rewrite is indistinguishable from a working one until
            -- somebody runs the program on a machine that is not this one.
            local out = os.iorun(string.format([[readelf -d "%s"]], exe)) or ""
            if out:find("(RPATH)", 1, true) then patched = patched + 1
            else table.insert(skipped, prog) end
        end
    end
    if #skipped > 0 then
        log.warn("dpcpp: %d program(s) still carry no DT_RPATH (%s); they will not "
                 .. "find this payload's own libraries. Is xim:patchelf installed?",
                 #skipped, table.concat(skipped, ", "))
    end
    log.debug("dpcpp: %d program(s) given a transitive search path", patched)
end

function install()
    local file = pkginfo.install_file() or ""
    local src  = path.directory(file)

    -- Before anything is moved: is this the payload we asked for?
    for _, required in ipairs(required_files()) do
        if not os.isfile(path.join(src, required)) then
            error("dpcpp: the unpacked archive is missing " .. required
                  .. "; refusing to move anything out of the shared download "
                  .. "directory")
        end
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    for _, e in ipairs(ENTRIES) do
        local from = path.join(src, e)
        if os.isdir(from) then os.mv(from, path.join(dir, e)) end
    end

    for _, required in ipairs(required_files()) do
        if not os.isfile(path.join(dir, required)) then
            error("dpcpp: payload is incomplete after the move; missing " .. required)
        end
    end
    if is_host("linux") then patch_program_rpaths(dir) end

    log.info("dpcpp installed to %s", dir)
    return true
end

function config()
    local dir     = pkginfo.install_dir()
    local bindir  = path.join(dir, "bin")
    local binding = package.name .. "@" .. pkginfo.version()

    -- The SYCL compiler ships under clang's names, not `dpcpp`, so the root is
    -- added bare and the programs are named individually. `icpx` is the oneAPI
    -- spelling and is present in this build as a driver alias.
    xvm.add(package.name)

    -- The alias keeps its bare name on every host -- `mcpp` and the shims ask
    -- for `clang++`, not `clang++.exe` -- while the file that has to exist is
    -- the one on disk.
    local exe = is_host("windows") and ".exe" or ""
    local n = 0
    for _, prog in ipairs({ "clang++", "clang", "sycl-ls", "clang-linker-wrapper",
                            "clang-offload-bundler", "llvm-offload-binary" }) do
        if os.isfile(path.join(bindir, prog .. exe)) then
            xvm.add(prog, { bindir = bindir, alias = prog, binding = binding })
            n = n + 1
        end
    end
    if n == 0 then
        log.error("dpcpp: payload registered no programs")
        return false
    end
    return true
end

function uninstall()
    os.tryrm(pkginfo.install_dir())
    return true
end
