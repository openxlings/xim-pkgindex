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

function install()
    -- The asset is a FLAT archive: bin/, lib/, include/ at the top level with
    -- no wrapping directory. Unpacking it beside other downloads and then
    -- moving "the one directory" would move the wrong thing, so the download
    -- directory itself is the payload root.
    local file = pkginfo.install_file() or ""
    local src  = path.directory(file)
    if not os.isdir(path.join(src, "bin")) then
        error("dpcpp: the archive did not unpack to a flat prefix (no bin/)")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    os.cp(path.join(src, "*"), dir)

    for _, required in ipairs({ "bin/clang++", "bin/sycl-ls", "lib/libsycl.so" }) do
        if not os.isfile(path.join(dir, required)) then
            error("dpcpp: payload is incomplete; missing " .. required)
        end
    end
    log.info("dpcpp installed to %s", dir)
    return true
end

-- WHAT GETS REGISTERED, AND WHY IT IS SCANNED
--
-- These components differ in shape: some carry only `bin/` (nvcc, cuda-gdb),
-- some only `lib/` and `include/` (cudart, libnvvm), some both. Registering a
-- hand-written list per component would be a table to keep in step with
-- upstream's packaging, and upstream has already moved files between
-- components once between the 12.x and 13.x lines.
--
-- So the payload is scanned. What matters for the version machinery is that
-- `xvm.add(package.name)` names the root -- that is what `xlings use
-- <pkg> <version>` switches -- and that each program and library is bound to
-- `<pkg>@<version>`, so two release lines can be installed side by side and
-- selected rather than fighting.
--
-- A component that registers nothing at all is not a partial result, it is the
-- wrong payload: reported as an error rather than a successful install of
-- nothing.
local function register_dir(dir, kind, binding, count)
    if not os.isdir(dir) then return count end
    -- `io.popen` rather than `os.files`: the recipe sandbox does not expose the
    -- latter in `config()` -- it fails with `attempt to call a nil value
    -- (field 'files')` -- and `io.popen` is what the index's other payload
    -- recipes use for the same job. These components declare `linux` only, so
    -- one POSIX listing is the whole story; a Windows entry would need the
    -- `dir /b` branch llvm.lua carries, and would be added with that entry.
    local pattern = (kind == "lib") and "-type f -name '*.so*' -o -type f -name '*.a'"
                                     or "-maxdepth 1 -type f -perm -u+x"
    local cmd
    if kind == "lib" then
        cmd = string.format([[find "%s" -maxdepth 1 \( %s \) 2>/dev/null]], dir, pattern)
    else
        cmd = string.format([[find "%s" %s 2>/dev/null]], dir, pattern)
    end
    local f = io.popen(cmd)
    if not f then return count end
    for line in f:lines() do
        local full = line:gsub("[\r\n]+$", "")
        if full ~= "" then
            local base = path.filename(full)
            if kind == "lib" then
                xvm.add(base, {
                    type = "lib", bindir = dir, filename = base,
                    alias = base, binding = binding,
                })
            else
                xvm.add((base:gsub("%.exe$", "")), {
                    bindir = dir, alias = base, binding = binding,
                })
            end
            count = count + 1
        end
    end
    f:close()
    return count
end

function config()
    local dir     = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    local n = 0
    n = register_dir(path.join(dir, "bin"), "bin", binding, n)
    n = register_dir(path.join(dir, "lib"), "lib", binding, n)
    n = register_dir(path.join(dir, "nvvm", "bin"), "bin", binding, n)
    n = register_dir(path.join(dir, "nvvm", "lib64"), "lib", binding, n)

    if n == 0 and not os.isdir(path.join(dir, "include")) then
        log.error("%s: payload contains no programs, libraries or headers",
                  package.name)
        return false
    end
    return true
end

function uninstall()
    os.tryrm(pkginfo.install_dir())
    return true
end
