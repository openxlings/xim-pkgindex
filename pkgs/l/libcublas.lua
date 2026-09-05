-- libcublas — the NVIDIA CUDA redistributable component `libcublas`.
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

    name = "libcublas",
    description = "CUDA libcublas: dense linear algebra on the device",

    maintainers = {"NVIDIA"},
    licenses = {"CUDA Toolkit"},
    repo = "https://developer.download.nvidia.com/compute/cuda/redist",
    docs = "https://docs.nvidia.com/cuda",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"math", "gpu", "nvidia", "cuda"},
    keywords = {"cuda", "nvidia", "gpu", "libcublas"},

    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://developer.download.nvidia.com/compute/cuda/redist/"
                  .. "libcublas/linux-${arch_alias}/"
                  .. "libcublas-linux-${arch_alias}-${version}-archive.tar.xz",
            arch_alias = { x86_64 = "x86_64", aarch64 = "sbsa" },
            ["latest"] = { ref = "13.5.1.27" },
            ["13.5.1.27"] = {
                sha256 = {
                    aarch64  = "cdcfea21e8a68ce90c87aaf2e424883782dafb4792feb4e6ea903b97e9aeb6a7",
                    x86_64   = "35a898360520d6101ffcaf36c0d04496b54d4fc2afb82f7fce44218c54513808",
                },
            },
            ["12.9.1.4"] = {
                sha256 = {
                    aarch64  = "e99b074e6f66034e563508118804599d7579f73afc8424c55ad5fd8d12e085a5",
                    x86_64   = "546addc4a9d82b8f23aa9ba9274b6bc0429a63008a31c759884ac24880796057",
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
        error("libcublas: the downloaded archive did not unpack to a recognisable "
              .. "component directory")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)
    log.info("libcublas installed to %s", dir)
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
