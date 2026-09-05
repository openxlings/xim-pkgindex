-- cuda-cccl — the NVIDIA CUDA redistributable component `cuda_cccl`.
--
-- WHY ONE PACKAGE PER UPSTREAM COMPONENT
--
-- NVIDIA publishes the toolkit as independently versioned components with a
-- machine-readable manifest (redistrib_<release>.json) carrying each one's
-- URL, size and SHA-256. Mirroring that split means a consumer installs what
-- it uses: a build that only compiles device code takes nvcc and its back end,
-- and does not take a 336 MB profiler.
--
-- WHY NO CROSS-COMPONENT `deps`
--
-- The set a working nvcc needs is not the same across releases. In the 12.x
-- line `cuda_nvcc` carries its own NVVM back end; in 13.x that became a
-- separate `libnvvm`, alongside `cuda_crt`, `libnvptxcompiler` and
-- `cuda_culibos`. `xpm.<platform>.deps` is declared per platform and cannot
-- vary per version, so encoding either shape here would be wrong for the other
-- line.
--
-- The closure is therefore discovered rather than declared: `nvcc --dryrun`
-- states the stages it will invoke and the search path it will use, and mcpp
-- reads that plan and reports the first stage that does not resolve, naming
-- the component to install. Knowledge of the vendor's component layout belongs
-- to the rule package that drives nvcc, not to this recipe.
--
-- VERSION
--
-- The version is upstream's, verbatim from the manifest's `version` field.
-- Two release lines are carried on purpose: the CUDA runtime a binary is built
-- against must not be newer than the host driver, and the driver is the one
-- component that cannot be redistributed. A machine whose driver reports CUDA
-- 12.4 builds against the 12.x line; 13.x requires a newer driver.
--
-- LICENCE
--
-- Upstream states `CCCL EULA` for this component. The URL below points at
-- NVIDIA's own distribution host, so nothing is re-hosted here.
package = {
    spec = "1",

    name = "cuda-cccl",
    description = "CUDA cuda_cccl: Thrust, CUB and libcu++",

    maintainers = {"NVIDIA"},
    licenses = {"CCCL EULA"},
    repo = "https://developer.download.nvidia.com/compute/cuda/redist",
    docs = "https://docs.nvidia.com/cuda",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "gpu", "nvidia", "cuda"},
    keywords = {"cuda", "nvidia", "gpu", "cuda_cccl"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- ⚠️ NO `source` TEMPLATE HERE, AND THAT IS THE POINT.
            --
            -- Upstream RENAMED this component between release lines: the 12.x
            -- manifests call it `cuda_cccl`, the 13.x ones call it `cccl`, and
            -- the directory is part of the URL. One template cannot serve both,
            -- and a template built from either name 404s on the other line --
            -- which is how this was found, not by reading the manifest.
            --
            -- Explicit per-version, per-arch URLs instead. The version keys
            -- stay upstream's, including 13.x's four-segment `13.3.3.3.1`.
            ["latest"] = { ref = "13.3.3.3.1" },
            -- upstream directory: `cccl`
            ["13.3.3.3.1"] = {
                aarch64  = {
                    url    = "https://developer.download.nvidia.com/compute/cuda/redist/cccl/linux-sbsa/cccl-linux-sbsa-13.3.3.3.1-archive.tar.xz",
                    sha256 = "37e9024c5e24a9e9d1618c4fb7b36e74a0a68fac91d589867676952204ecde5b",
                },
                x86_64   = {
                    url    = "https://developer.download.nvidia.com/compute/cuda/redist/cccl/linux-x86_64/cccl-linux-x86_64-13.3.3.3.1-archive.tar.xz",
                    sha256 = "67746da12f16229ac4ebde78ce7895e42b069d1d3e2ae2d2d25f90bc43679d68",
                },
            },
            -- upstream directory: `cuda_cccl`
            ["12.9.27"] = {
                aarch64  = {
                    url    = "https://developer.download.nvidia.com/compute/cuda/redist/cuda_cccl/linux-sbsa/cuda_cccl-linux-sbsa-12.9.27-archive.tar.xz",
                    sha256 = "8c3da24801b500f1d9217d191bb4b63e5d2096c8e7d0b7695e876853180ba82f",
                },
                x86_64   = {
                    url    = "https://developer.download.nvidia.com/compute/cuda/redist/cuda_cccl/linux-x86_64/cuda_cccl-linux-x86_64-12.9.27-archive.tar.xz",
                    sha256 = "8b1a5095669e94f2f9afd7715533314d418179e9452be61e2fde4c82a3e542aa",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The archive unpacks to `cuda_cccl-linux-<arch>-<version>-archive/`.
-- Locate it by scanning rather than by rebuilding the name: a re-pack or a
-- stray sibling would otherwise install the wrong tree silently.
local function payload_root()
    local file = pkginfo.install_file() or ""
    local base = path.directory(file)
    local stem = (file:match("[^/\\]+$") or ""):gsub("%.tar%.xz$", "")
    if stem ~= "" and os.isdir(path.join(base, stem)) then
        return path.join(base, stem)
    end
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "LICENSE")) or os.isdir(path.join(d, "bin"))
           or os.isdir(path.join(d, "include")) or os.isdir(path.join(d, "lib")) then
            return d
        end
    end
    return nil
end

function install()
    local src = payload_root()
    if not src then
        error("cuda-cccl: the downloaded archive did not unpack to a recognisable "
              .. "component directory")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)
    log.info("cuda-cccl installed to %s", dir)
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
