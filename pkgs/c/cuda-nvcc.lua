-- cuda-nvcc — the NVIDIA CUDA redistributable component `cuda_nvcc`.
--
-- WHY ONE PACKAGE PER UPSTREAM COMPONENT
--
-- NVIDIA publishes the toolkit as independently versioned components with a
-- machine-readable manifest (redistrib_<release>.json) carrying each one's
-- URL, size and SHA-256. Mirroring that split means a consumer installs what
-- it uses: a build that only compiles device code takes nvcc and its back end,
-- and does not take a 336 MB profiler.
--
-- WHY THE BACK-END CLOSURE IS INSTALLED HERE AND NOT DECLARED IN `deps`
--
-- The set a working nvcc needs is not the same across releases. In the 12.x
-- line `cuda_nvcc` carries its own NVVM back end; in 13.x that became a
-- separate `libnvvm`, alongside `cuda_crt`, `libnvptxcompiler` and
-- `cuda_culibos`. `xpm.<platform>.deps` is declared per platform and cannot
-- vary per version, so either shape written there would be wrong for the other
-- line.
--
-- `install()` therefore installs the closure the INSTALLED VERSION needs,
-- through `pkgmanager`. The compiler-side components share nvcc's own version
-- (13.3.33 for all four in the 13.3 release), so one version answers for all
-- of them; `cuda_cudart` and `cccl` version separately and are not installed
-- here, because a build that only compiles does not need them.
--
-- Second line of defence, independent of this one: `nvcc --dryrun` states the
-- stages it will invoke and the search path it will use. mcpp reads that plan
-- and reports the first stage that does not resolve. An incomplete payload is
-- therefore named at build time even if this hook was skipped.
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
-- Upstream states `CUDA Toolkit` for this component. The URL below points at
-- NVIDIA's own distribution host, so nothing is re-hosted here.
package = {
    spec = "1",

    name = "cuda-nvcc",
    description = "CUDA cuda_nvcc: nvcc and the compiler driver's own back-end stages",

    maintainers = {"NVIDIA"},
    licenses = {"CUDA Toolkit"},
    repo = "https://developer.download.nvidia.com/compute/cuda/redist",
    docs = "https://docs.nvidia.com/cuda",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "gpu", "nvidia", "cuda"},
    keywords = {"cuda", "nvidia", "gpu", "cuda_nvcc"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- `sbsa` is upstream's name for 64-bit Arm servers; xlings spells
            -- the same architecture `aarch64`. The alias absorbs the
            -- difference rather than a second source line.
            source = "https://developer.download.nvidia.com/compute/cuda/redist/"
                  .. "cuda_nvcc/linux-${arch_alias}/"
                  .. "cuda_nvcc-linux-${arch_alias}-${version}-archive.tar.xz",
            arch_alias = { x86_64 = "x86_64", aarch64 = "sbsa" },
            ["latest"] = { ref = "13.3.33" },
            ["13.3.33"] = {
                sha256 = {
                    aarch64  = "b5dde44aadd52234af3944ae3b2e74e811ad8e71fb600bcc9dfe6d8540353499",
                    x86_64   = "93b098bda4a562ebf3541523ce82adc43f106a81dcf28bcbf8f0d8e093d1c66f",
                },
            },
            ["12.9.86"] = {
                sha256 = {
                    aarch64  = "0aa1fce92dbae76c059c27eefb9d0ffb58e1291151e44ff7c7f1fc2dd9376c0d",
                    x86_64   = "7a1a5b652e5ef85c82b721d10672fc9a2dbaab44e9bd3c65a69517bf53998c35",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The major version, as a number. `13.3.33` -> 13.
local function major_of(ver)
    return tonumber((tostring(ver):match("^(%d+)")) or "0") or 0
end

-- What this release split out of `cuda_nvcc`. Empty before 13.x, where the
-- component carried its own back end.
local function backend_components(ver)
    if major_of(ver) >= 13 then
        return { "libnvvm", "cuda-crt", "libnvptxcompiler", "cuda-culibos" }
    end
    return {}
end

-- The archive unpacks to `cuda_nvcc-linux-<arch>-<version>-archive/`.
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
        error("cuda-nvcc: the downloaded archive did not unpack to a recognisable "
              .. "component directory")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)

    -- The back end this release keeps outside `cuda_nvcc`. Installed at nvcc's
    -- own version: the four compiler-side components are versioned together
    -- with it upstream.
    local ver = pkginfo.version()
    for _, c in ipairs(backend_components(ver)) do
        log.info("cuda-nvcc: installing back-end component %s@%s", c, ver)
        pkgmanager.install(c .. "@" .. ver)
    end

    log.info("cuda-nvcc installed to %s", dir)
    return true
end

-- WHAT GETS REGISTERED, AND WHY IT IS SCANNED
--
-- These components differ in shape, and the differences are not guessable:
--
--   cuda-nvcc        bin/ and nvvm/bin/
--   cuda-cudart      lib/ and include/, no programs at all
--   cuda-gdb         bin/, and one of its programs is named after the package
--   nsight-compute   NO bin/ -- `ncu` and `ncu-ui` sit at the payload root,
--                    beside host/ and target/
--
-- A hand-written list per component would be a table to keep in step with
-- upstream, and upstream has already moved files between components once
-- between the 12.x and 13.x lines. So the payload is scanned, in the four
-- places these layouts put things.
--
-- ⚠️ A PROGRAM NAMED AFTER ITS PACKAGE IS REGISTERED ONCE, NOT TWICE.
-- `xvm.add(package.name)` names the root, which is what `xlings use <pkg>
-- <version>` switches. `cuda-gdb` ships `bin/cuda-gdb`, so adding that as a
-- program as well trips xvm's duplicate-registration check and the whole
-- config hook fails -- which is exactly what CI reported before this. The root
-- therefore carries the binding when such a program exists, and is added bare
-- otherwise.
local function scan_dir(dir, kind)
    local out = {}
    if not os.isdir(dir) then return out end
    -- `io.popen` rather than `os.files`: the recipe sandbox does not expose the
    -- latter in `config()` (`attempt to call a nil value (field 'files')`), and
    -- `io.popen` is what this index's other payload recipes use for the job.
    -- These components declare `linux` only, so one POSIX listing is the whole
    -- story.
    -- ⚠️ `-type f` WOULD SKIP SYMLINKS, AND SOME PAYLOADS SHIP ONLY SYMLINKS
    -- IN `bin/`. nsight-systems is that case: `bin/nsys` and `bin/nsys-ui`
    -- point at `../target-linux-x64/nsys` and `../host-linux-x64/nsys-ui`, and
    -- a scan restricted to regular files reported the payload as containing no
    -- programs -- which is what CI said, twice.
    --
    -- `-executable` asks the question that is actually being asked, and it
    -- follows the link. Libraries are matched by name for the same reason: a
    -- versioned soname is usually a symlink to the real object.
    local cmd
    if kind == "lib" then
        cmd = string.format(
            [[find "%s" -maxdepth 1 \( -name '*.so*' -o -name '*.a' \) 2>/dev/null]], dir)
    else
        cmd = string.format([[find "%s" -maxdepth 1 ! -type d -executable 2>/dev/null]], dir)
    end
    local f = io.popen(cmd)
    if not f then return out end
    for line in f:lines() do
        local full = line:gsub("[\r\n]+$", "")
        if full ~= "" then table.insert(out, full) end
    end
    f:close()
    return out
end

function config()
    local dir     = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    local programs, libs = {}, {}
    for _, d in ipairs({ path.join(dir, "bin"), path.join(dir, "nvvm", "bin"), dir }) do
        for _, f in ipairs(scan_dir(d, "bin")) do table.insert(programs, f) end
    end
    for _, d in ipairs({ path.join(dir, "lib"), path.join(dir, "lib64"),
                         path.join(dir, "nvvm", "lib64") }) do
        for _, f in ipairs(scan_dir(d, "lib")) do table.insert(libs, f) end
    end

    -- Does the payload ship a program named after the package?
    local eponymous = nil
    for _, f in ipairs(programs) do
        if path.filename(f):gsub("%.exe$", "") == package.name then eponymous = f end
    end

    -- ⚠️ NO `binding` ON THE ROOT. The binding names the node a registration
    -- resolves through, and xvm refuses `registration node cannot bind to
    -- itself` -- which is what CI reported. The root carries the bindir
    -- directly, exactly as cmake.lua does for its own eponymous program; the
    -- other programs bind THROUGH the root.
    if eponymous then
        xvm.add(package.name, {
            bindir = path.directory(eponymous),
            alias  = path.filename(eponymous),
        })
    else
        xvm.add(package.name)
    end

    local n = 0
    for _, f in ipairs(programs) do
        local base = path.filename(f)
        if f ~= eponymous then
            xvm.add((base:gsub("%.exe$", "")), {
                bindir = path.directory(f), alias = base, binding = binding,
            })
        end
        n = n + 1
    end
    for _, f in ipairs(libs) do
        local base = path.filename(f)
        xvm.add(base, {
            type = "lib", bindir = path.directory(f), filename = base,
            alias = base, binding = binding,
        })
        n = n + 1
    end

    -- A component that registers nothing and carries no headers is not a
    -- partial result, it is the wrong payload.
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
