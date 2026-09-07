-- libcurand — the NVIDIA CUDA redistributable component `libcurand`.
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
    -- THE WINDOWS SECTION CARRIES THE 12.x LINE ONLY, AND THAT IS A DECISION
    -- ABOUT THE RELEASE LINE RATHER THAN ABOUT THIS COMPONENT.
    --
    -- These components are versioned together upstream, and a consumer chooses
    -- a line rather than a component: nvcc 12.9 with cudart 13.3 is not a
    -- pairing NVIDIA publishes or supports. On the 13.x line `cuda_nvcc` no
    -- longer contains its own back end -- `nvvm/` and `crt/` were split into
    -- four separately published components, which this index reunites with
    -- symlinks, and `ln` is not a command on Windows. Until that reunification
    -- has a Windows form, 13.x cannot be published there; and publishing 13.x
    -- for the components that individually could would offer a Windows
    -- `latest` that pairs with an nvcc which does not exist on that host.
    --
    -- Declared rather than left to be read off the file, so this is visibly a
    -- decision and not a bump that landed in one section and was forgotten in
    -- the other.
    platform_versions_diverge = true,
    spec = "1",

    name = "libcurand",
    description = "CUDA libcurand: random number generation",

    maintainers = {"NVIDIA"},
    licenses = {"CUDA Toolkit"},
    repo = "https://developer.download.nvidia.com/compute/cuda/redist",
    docs = "https://docs.nvidia.com/cuda",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"math", "gpu", "nvidia", "cuda"},
    keywords = {"cuda", "nvidia", "gpu", "libcurand"},

    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://developer.download.nvidia.com/compute/cuda/redist/"
                  .. "libcurand/linux-${arch_alias}/"
                  .. "libcurand-linux-${arch_alias}-${version}-archive.tar.xz",
            arch_alias = { x86_64 = "x86_64", aarch64 = "sbsa" },
            ["latest"] = { ref = "10.4.3.29" },
            ["10.4.3.29"] = {
                sha256 = {
                    aarch64  = "3c2245e848ff8948663646ad7870cc8451b7cf1726758bedff7c123011126e4b",
                    x86_64   = "0218e62ab413e435dcd0274ec8e63b62214e6aba8519201061d1597e73caadbb",
                },
            },
            ["10.3.10.19"] = {
                sha256 = {
                    aarch64  = "078afec842c99b3a953d62cc76bd74afa2d883dc436e6d642e6440bb1e85eb8e",
                    x86_64   = "48281b4caadb1cf790d44ac76b23c77d06f474c0b1799814f314aafec9258ad6",
                },
            },
        },

        -- WINDOWS CARRIES THE 12.9 LINE ONLY, and the reason is the 13.x back
        -- end rather than the platform. Upstream split `nvvm/` and `crt/` out
        -- of `cuda_nvcc` on the 13.x line into four separate components, which
        -- this index installs as four more packages and then reunites; porting
        -- that here means Windows blocks for `libnvvm`, `cuda-crt`,
        -- `libnvptxcompiler` and `cuda-culibos` and a reunification nothing in
        -- CI can check on Windows yet. 12.9 keeps its back end inside the
        -- component, so it needs none of that.
        --
        -- `latest` therefore differs per platform. A consumer that pins -- which
        -- is what the rule packages do -- never sees it; one that does not gets
        -- the line this platform has been verified on.
        windows = {
            source = "https://developer.download.nvidia.com/compute/cuda/redist/"
                  .. "libcurand/windows-x86_64/"
                  .. "libcurand-windows-x86_64-${version}-archive.zip",
            ["latest"] = { ref = "10.3.10.19" },
            ["10.3.10.19"] = {
                sha256 = { x86_64 = "d0411f0b8c07e90d0fb6e01bfa7a54c9cb80f2ddf67e4ded2d96a50e19aadad6" },
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
    -- `.zip` as well as `.tar.xz`: the Windows components are published as
    -- zips, and a stem that still carries its extension matches no directory,
    -- so the lookup would fall through to the scan below -- which searches a
    -- SHARED download directory and would return whichever sibling package
    -- happened to unpack a `bin/` there first.
    local stem = (file:match("[^/\\]+$") or ""):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
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
        error("libcurand: the downloaded archive did not unpack to a recognisable "
              .. "component directory")
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)
    log.info("libcurand installed to %s", dir)
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
    -- ⚠️ `-type f` WOULD SKIP SYMLINKS, AND SOME PAYLOADS SHIP ONLY SYMLINKS
    -- IN `bin/`. nsight-systems is that case: `bin/nsys` and `bin/nsys-ui`
    -- point at `../target-linux-x64/nsys` and `../host-linux-x64/nsys-ui`, and
    -- a scan restricted to regular files reported the payload as containing no
    -- programs -- which is what CI said, twice.
    --
    -- `-executable` asks the question that is actually being asked, and it
    -- follows the link. Libraries are matched by name for the same reason: a
    -- versioned soname is usually a symlink to the real object.
    --
    -- THE WINDOWS LISTING IS A DIFFERENT COMMAND, NOT A DIFFERENT PATTERN.
    -- `find` on a Windows runner is `C:\Windows\System32\find.exe`, which
    -- searches file CONTENTS for a string and rejects every flag used here, so
    -- a shared invocation does not fail loudly -- it prints a usage error to
    -- stderr, which `2>nul` would hide, and returns nothing. A component that
    -- registers nothing looks exactly like a component with no programs.
    --
    -- cmd's `dir` takes several patterns at once and prints bare names under
    -- `/b`, so the directory is prepended below. Backslashes because an
    -- unquoted `/` is a switch character to cmd.
    local cmd, bare
    if is_host("windows") then
        bare = true
        if kind == "lib" then return out end
        cmd = string.format([[dir /b /a-d "%s\*.exe" 2>nul]], dir:gsub("/", "\\"))
    elseif kind == "lib" then
        cmd = string.format(
            [[find "%s" -maxdepth 1 \( -name '*.so*' -o -name '*.a' \) 2>/dev/null]], dir)
    else
        cmd = string.format([[find "%s" -maxdepth 1 ! -type d -executable 2>/dev/null]], dir)
    end
    local f = io.popen(cmd)
    if not f then return out end
    for line in f:lines() do
        local full = line:gsub("[\r\n]+$", "")
        if full ~= "" then table.insert(out, bare and path.join(dir, full) or full) end
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
