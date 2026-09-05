-- cuda-gdb — the NVIDIA CUDA redistributable component `cuda_gdb`.
--
-- One package per upstream component, so a consumer installs what it uses.
-- The version is upstream's, verbatim from the manifest's `version` field;
-- two release lines are carried because the CUDA runtime a binary is built
-- against must not be newer than the host driver.
--
-- LICENCE
--
-- Upstream states `CUDA Toolkit` for this component. The URL points at NVIDIA's own
-- distribution host, so nothing is re-hosted here.
package = {
    spec = "1",

    name = "cuda-gdb",
    description = "CUDA cuda_gdb: the CUDA debugger",

    maintainers = {"NVIDIA"},
    licenses = {"CUDA Toolkit"},
    repo = "https://developer.download.nvidia.com/compute/cuda/redist",
    docs = "https://docs.nvidia.com/cuda",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"debug", "gpu", "nvidia", "cuda"},
    keywords = {"cuda", "nvidia", "gpu", "cuda_gdb"},

    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://developer.download.nvidia.com/compute/cuda/redist/"
                  .. "cuda_gdb/linux-${arch_alias}/"
                  .. "cuda_gdb-linux-${arch_alias}-${version}-archive.tar.xz",
            arch_alias = { x86_64 = "x86_64", aarch64 = "sbsa" },
            ["latest"] = { ref = "13.3.27" },
            ["13.3.27"] = {
                sha256 = {
                    aarch64  = "5ca08ce62a5dc1a2c6810e5ab4caeb52eac91a58cc7077e33ed0ce1cfee486fe",
                    x86_64   = "4dd9e2f93ff27c19a5536e10d73d8b209efd5cb73f59abca9d04de4c6c837ce3",
                },
            },
            ["12.9.79"] = {
                sha256 = {
                    aarch64  = "251b9bd86ffcce0cdc4a5480ef3d8d609ca3a276cbbb5c793ca9978721d31faf",
                    x86_64   = "3dbb657683cd4f2989c30bdad31b3f4493795a9acc8a2214f48df3cfca7c37c0",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

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
        error("cuda-gdb: the downloaded archive did not unpack to a recognisable "
              .. "component directory")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)
    log.info("cuda-gdb installed to %s", dir)
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
    local cmd
    if kind == "lib" then
        cmd = string.format(
            [[find "%s" -maxdepth 1 \( -name '*.so*' -o -name '*.a' \) -type f 2>/dev/null]], dir)
    else
        cmd = string.format([[find "%s" -maxdepth 1 -type f -perm -u+x 2>/dev/null]], dir)
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
