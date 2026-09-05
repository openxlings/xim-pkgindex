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
-- The same notes state that "HIP & CUDA plugins on Windows are not being
-- built". A Windows entry therefore cannot be a repack of the official asset
-- if those backends are wanted there; it has to be built. The version would
-- still be `7.1.0`, because that is the source it is built from.
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
            source = "https://github.com/intel/llvm/releases/download/v${version}/sycl_linux.tar.gz",
            ["latest"] = { ref = "7.1.0" },
            ["7.1.0"] = {
                sha256 = {
                    x86_64 = "992de12d5c68ba8fd630446b1a97487361b38807b33140769e4c818795f0fcab",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.elfpatch")

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

function install()
    local file = pkginfo.install_file() or ""
    local src  = path.directory(file)

    -- Before anything is moved: is this the payload we asked for?
    for _, required in ipairs({ path.join("bin", "clang++"),
                                path.join("bin", "sycl-ls"),
                                path.join("lib", "libsycl.so") }) do
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

    for _, required in ipairs({ "bin/clang++", "bin/sycl-ls", "lib/libsycl.so" }) do
        if not os.isfile(path.join(dir, required)) then
            error("dpcpp: payload is incomplete after the move; missing " .. required)
        end
    end
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
    -- set_rpath, NOT selfcontain.seal, AND THE DIFFERENCE IS THE LOADER.
    --
    -- `selfcontain.seal` calls `patch_elf_loader_rpath`, which sets the
    -- INTERPRETER as well as the search path. A payload patched that way runs
    -- under the ecosystem's private loader, and behind that loader there is no
    -- host fallback: its ld.so.cache path exists on no machine. This payload
    -- is not closed over. Its Unified Runtime adapters need `libcuda.so.1`,
    -- `libnvidia-ml.so.1`, `libcupti.so.12`, `libOpenCL.so.1` and `libz.so.1`,
    -- and this index publishes a provider for only some of them. Sealing was
    -- tried: CI's dependency-closure check refused it and named the four with
    -- no provider, and the sealed payload enumerated NO platforms where the
    -- unsealed one had found the GPU -- the check was describing a real
    -- regression, not a formality.
    --
    -- So this is the smallest change that answers the defect: give the five
    -- programs the same relative search path the other programs in this same
    -- payload already carry, and change nothing about which loader they run
    -- under or where their other dependencies come from. Closing the payload
    -- properly needs a CUPTI payload, an OpenCL loader package and the NVIDIA
    -- userspace sentinel; that is a packaging round of its own and is recorded
    -- here rather than half-done.
    --
    -- BOTH HALVES, AND THE LIBRARY HALF IS WHAT MAKES THE DEVICE APPEAR.
    --
    -- Giving only bin/ a search path makes the five programs start and leaves
    -- `sycl-ls` reporting no platforms at all. The Unified Runtime loader
    -- dlopens its adapters by absolute path, so they are found -- and then
    -- each one fails on `libumf.so.1`, which is IN THIS PAYLOAD'S OWN lib/ and
    -- which the adapters, carrying no search path of their own, cannot see.
    -- The measurement that separates the two: with bin/ alone, every adapter
    -- reports `libumf.so.1: cannot open shared object file`; with both, the
    -- CUDA adapter loads and the device is enumerated.
    --
    -- $ORIGIN keeps this relative, so the payload answers from wherever it is
    -- unpacked, and nothing outside the payload is named -- the adapters'
    -- remaining needs (`libcuda.so.1`, `libnvidia-ml.so.1`) still resolve the
    -- way they did before this change, through the host loader's cache. A
    -- RUNPATH adds a directory to that search; it does not replace it.
    --
    -- `shrink = false`: --shrink-rpath keeps only the entries that satisfy a
    -- current DT_NEEDED, which is the wrong answer for a directory something
    -- will dlopen out of later.
    elfpatch.set_rpath(path.join(dir, "bin"), { "$ORIGIN/../lib" }, { shrink = false })
    elfpatch.set_rpath(path.join(dir, "lib"), { "$ORIGIN" },        { shrink = false })

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

    local n = 0
    for _, prog in ipairs({ "clang++", "clang", "sycl-ls", "clang-linker-wrapper",
                            "clang-offload-bundler", "llvm-offload-binary" }) do
        if os.isfile(path.join(bindir, prog)) then
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
