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
import("xim.libxpkg.system")

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

-- ⚠️⚠️ WHAT SPLITTING THE COMPONENT BROKE, AND WHY NOTHING REPORTED IT.
--
-- nvcc addresses its own back end through `bin/nvcc.profile`, which reads
--
--     TOP                = $(_HERE_)/..
--     CICC_PATH          = $(TOP)/nvvm/bin
--     NVVMIR_LIBRARY_DIR = $(TOP)/nvvm/libdevice
--
-- On the 12.x line `nvvm/` sat inside `cuda_nvcc` and those paths resolved. On
-- the 13.x line upstream moved it to `libnvvm`, and `crt/` to `cuda_crt` —
-- separate archives, and here separate payload roots. Installing all four
-- therefore produces an nvcc that cannot compile anything:
--
--     sh: 1: .../xim-x-cuda-nvcc/13.3.33/bin/../nvvm/bin/cicc: not found
--
-- ⭐ Every obvious check passes. The payload is complete, `nvcc` is on `PATH`,
-- `--version` answers, and the component that holds `cicc` IS installed —
-- one directory level away from where nvcc looks. Measured 2026-09-05.
--
-- The repair restores the ONE layout property nvcc's own machinery depends on,
-- and only for the components upstream versions together with nvcc, so no
-- independently versioned component is pinned by it. A symlink rather than a
-- copy: the component payload stays the single copy on disk, and
-- `xlings use cuda-nvcc <other version>` continues to switch whole trees.
-- Where a sibling component of the same release sits in this store.
--
-- ⚠️ `pkginfo.install_dir("xim:libnvvm", ver)` cannot answer: since libxpkg
-- 0.0.57 it resolves only DECLARED dependencies, and these components cannot be
-- declared. `xpm.<os>.deps` is read at the OS level, not per version — every
-- key beside `deps` there IS a version — so one declaration would apply to the
-- 12.x line too, where `libnvvm` and `cuda-crt` are inside `cuda_nvcc` and the
-- separately published archives do not exist at that version. A dependency
-- that is right for one release line and wrong for the other is not a
-- dependency of the package.
--
-- So the sibling is derived, and only the two facts this store guarantees are
-- used: components of one namespace are siblings under one root, and the
-- directory name is `<namespace>-x-<package>`. The namespace is read off this
-- package's own directory rather than written down, so an index published
-- under another namespace derives its own.
local function sibling_payload(dir, comp, ver)
    local store  = path.directory(path.directory(dir))
    local mine   = path.filename(path.directory(dir))
    local prefix = mine:sub(1, #mine - #package.name)
    return path.join(store, prefix .. comp, ver)
end

local function reunite_backend(dir, ver)
    -- Keyed on what this release actually split out, so the 12.x line — where
    -- nothing was split — asks for nothing and reports nothing.
    local split = {}
    for _, c in ipairs(backend_components(ver)) do split[c] = true end
    local links = {
        { "libnvvm",  "nvvm",                       path.join(dir, "nvvm") },
        { "cuda-crt", path.join("include", "crt"),  path.join(dir, "include", "crt") },
    }
    for _, l in ipairs(links) do
        local comp, rel, into = l[1], l[2], l[3]
        -- `os.isdir`, not `os.exists`: the recipe sandbox does not expose the
        -- latter — `attempt to call a nil value (field 'exists')`, the same
        -- shape `register_dir` records for `os.files` — and every target here
        -- is a directory.
        if split[comp] and not os.isdir(into) then
            local from = path.join(sibling_payload(dir, comp, ver), rel)
            if not os.isdir(from) then
                error(string.format(
                    "cuda-nvcc: %s@%s carries %s and it was not found at %s; nvcc addresses "
                    .. "it through its own tree and cannot compile without it",
                    comp, ver, rel, from))
            end
            os.mkdir(path.directory(into))
            -- ⚠️ `ln` through the shell, not `os.ln` (absent from the recipe
            -- sandbox) and not `os.cp(..., { symlink = true })` — that flag
            -- means "preserve symlinks found in the source", so it copied the
            -- 47 MB tree instead of linking to it. `wsl-gl-host-link` already
            -- uses this spelling; these components declare `linux` only, so one
            -- POSIX form is the whole story.
            --
            -- A link, not a copy: the component payload stays the single copy
            -- on disk, and removing that component leaves a visibly broken link
            -- rather than a silently stale duplicate.
            system.exec(string.format([[ln -sfn "%s" "%s"]], from, into))
            log.info("cuda-nvcc: %s -> %s", into, from)
        end
    end
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

    reunite_backend(dir, ver)

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

    -- ⚠️ `nvvm/` IS SCANNED ONLY WHEN IT IS THIS PACKAGE'S OWN. On the 12.x line
    -- it is part of the archive and its programs belong here. On the 13.x line
    -- it is a link into `libnvvm`, whose own recipe registers `cicc` and
    -- `libnvvm.so` against `libnvvm@<version>`; scanning through the link would
    -- register the same files a second time under a second owner, and xvm
    -- rejects the duplicate, failing this package's config hook.
    local own_nvvm = #backend_components(pkginfo.version()) == 0
    local bindirs = { path.join(dir, "bin"), dir }
    local libdirs = { path.join(dir, "lib"), path.join(dir, "lib64") }
    if own_nvvm then
        table.insert(bindirs, 2, path.join(dir, "nvvm", "bin"))
        table.insert(libdirs, path.join(dir, "nvvm", "lib64"))
    end

    local programs, libs = {}, {}
    for _, d in ipairs(bindirs) do
        for _, f in ipairs(scan_dir(d, "bin")) do table.insert(programs, f) end
    end
    for _, d in ipairs(libdirs) do
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
