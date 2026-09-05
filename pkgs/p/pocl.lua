package = {
    spec = "2",

    homepage = "http://portablecl.org/",
    name = "pocl",
    description = "pocl -- OpenCL on the CPU, for machines with no GPU OpenCL platform",

    authors = {"pocl contributors"},
    -- The set, not the headline. This payload is a closure of 24 upstream
    -- packages and each one's terms travel with it; `licenses/` inside the
    -- payload carries the texts and `PROVENANCE.md` says which package
    -- contributed which. libgcc is GPL-3.0 with the runtime exception,
    -- libllvmspirv19 and llvm-spirv-19 are NCSA: none of the three is visible
    -- if only "MIT" (pocl's own licence) is written down.
    licenses = {
        "MIT", "Apache-2.0", "Apache-2.0 WITH LLVM-exception", "BSD-2-Clause",
        "BSD-3-Clause", "GPL-3.0-only WITH GCC-exception-3.1",
        "IJG AND BSD-3-Clause AND Zlib", "LGPL-2.1-only", "NCSA", "Zlib", "0BSD",
    },
    repo = "https://github.com/pocl/pocl",
    docs = "http://portablecl.org/docs/html/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compute", "opencl", "lib"},
    keywords = {"opencl", "pocl", "cpu", "compute", "llvm"},

    -- WHAT THIS PACKAGE IS FOR.
    --
    -- An OpenCL program needs a platform to enumerate before it needs a GPU:
    -- `clGetPlatformIDs` returning zero platforms is a different failure from
    -- "found a platform, no suitable device", and every CI runner in this
    -- ecosystem has no GPU and, absent this package, no OpenCL platform
    -- either. pocl answers that the same way mesa-lavapipe answers it for
    -- Vulkan: a device that is always available, because it is the CPU.
    --
    -- WHY A REPACK AND NOT A BUILD. pocl's own build pins an exact LLVM/Clang
    -- version and links `libclang-cpp.so` directly -- it drives Clang's
    -- Driver/CompilerInvocation C++ API IN-PROCESS to turn OpenCL C kernel
    -- source into LLVM IR at `clBuildProgram` time, not by shelling out to a
    -- `clang` executable (confirmed: the payload ships no `bin/clang` at all,
    -- and the probe below still built and ran a kernel). A source build
    -- inside this ecosystem's `xim:llvm` would need an exactly-matching
    -- `libclang-cpp`, which is not how that package is built or versioned;
    -- conda-forge already solves that pairing for every pocl release, and
    -- ships glibc-2.17-floor binaries with it. Recipe, scripts and
    -- measurements: https://github.com/xlings-res/pocl
    --
    -- NO `deps`, for the same reason and by the same rule as mesa-lavapipe:
    -- every `lib/*.so*` (and `bin/llvm-spirv-19`) carries `DT_RPATH =
    -- $ORIGIN` or `$ORIGIN/../lib`, written when the payload was assembled,
    -- and the closure -- LLVM 19, libclang-cpp, ocl-icd, libhwloc,
    -- libjpeg-turbo, spirv-tools -- is complete inside this one directory.
    -- Declaring a dependency here would hand the payload to predicate-driven
    -- elfpatch, which REPLACES DT_RPATH with a DT_RUNPATH of its own, and a
    -- non-empty DT_RUNPATH on a dlopen'd object switches off the
    -- EXECUTABLE's inherited DT_RPATH for that object's own dependencies --
    -- the same failure mesa-lavapipe's comment documents for the Vulkan ICD,
    -- here it would be ocl-icd's `libOpenCL.so.1` failing to resolve
    -- `libpocl.so`'s own LLVM/libclang-cpp/libhwloc dependencies.
    --
    -- NOTHING IS DECLARED INTO THE SUBOS LIBRARY VIEW. The payload contains
    -- an LLVM, a libclang-cpp, a libjpeg-turbo and an ocl-icd, and every one
    -- of them is a name some other package in this index also provides. They
    -- stay private to the payload; only the OpenCL ICD manifest is placed,
    -- into the one directory ocl-icd reads -- see `config()` and
    -- `graphics.declare_opencl_icd` for why that placement is NOT the
    -- zero-cost operation the Vulkan equivalent is.
    --
    -- CONDA BUILD-TIME PATHS BAKED INTO libpocl.so. `libpocl.so` locates its
    -- kernel bitcode and its own private OpenCL C headers (`share/pocl/`)
    -- through a COMPILED-IN absolute path -- this build has no
    -- dladdr()-relative relocation support -- and conda makes that path
    -- relocatable the same way it makes `bin/` scripts relocatable: the
    -- string is padded at build time to a fixed 255-byte placeholder
    -- (`_h_env_placehold_...`) that install() below finds and replaces
    -- byte-for-byte, keeping the file's length and every ELF offset after it
    -- unchanged. `strings lib/libpocl.so` on the x86_64 build shows three
    -- such occurrences (`share/pocl`, `bin/clang`, `bin/llvm-spirv-19`); the
    -- aarch64 build shows two -- its `bin/clang` reference is
    -- `_build_env/bin/clang`, a DIFFERENT, non-padded, non-relocatable string
    -- naming conda-forge's cross-build toolchain directory, which conda's own
    -- `has_prefix` metadata does not list either. install() tries both
    -- known builds' placeholder text against whatever `libpocl.so` shipped
    -- and applies whichever one is actually present, rather than asking
    -- `os.arch()` -- which this hook runtime does not reliably answer (see
    -- node.lua, perl.lua, jdk-zulu.lua for the same finding).
    xpm = {
        linux = {
            ["latest"] = { ref = "7.1" },
            ["7.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/pocl/releases/download/7.1/pocl-7.1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/pocl/releases/download/7.1/pocl-7.1-linux-x86_64.tar.gz",
                    },
                    sha256 = "c48bbffa8fc125db64671424b3f28020bed28dafaa4591f0e73468d32ccc8cea",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/pocl/releases/download/7.1/pocl-7.1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/pocl/releases/download/7.1/pocl-7.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "19c4d677e6cb2792041b80f75c01c1378438a34fb13d31adaaf671280cae65ee",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.pkgindex.graphics")

-- The conda build-prefix placeholder is 255 bytes, conda-forge's standard
-- padding length, chosen at BUILD time to be longer than any real install
-- path -- see the recipe's own comment above for what this is and why
-- `install()` cannot just ask which architecture it is running on. One entry
-- per upstream build actually fetched for this release; a future version
-- bump adds entries here rather than replacing them, in case a build's exact
-- placeholder text changes between point releases.
-- Each entry is exactly 255 bytes -- verified with `#entry == 255` against
-- the literal text recorded in that build's own `info/has_prefix`, not
-- retyped by hand from a `strings` dump (a one-token miscount here is
-- invisible in the source and turns every replacement into a silent no-op).
local CONDA_PLACEHOLDERS = {
    -- pocl-core 7.1 h411989e_2, linux-64 (conda-forge build_number 2)
    "/home/conda/feedstock_root/build_artifacts/pocl-core_1766656"
    .. "687165/_h_env_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_p",
    -- pocl-core 7.1 h58da6ad_2, linux-aarch64 (conda-forge build_number 2)
    "/home/conda/feedstock_root/build_artifacts/pocl-core_1766656"
    .. "805309/_h_env_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_placehold_placehold_placehold_placehold_placeh"
    .. "old_placehold_p",
}

-- Rewrite every occurrence of ONE placeholder prefix in a BINARY file the way
-- conda's own installer does: for each NUL-terminated string that starts
-- with `old_prefix`, keep the literal suffix that follows it (e.g.
-- `/share/pocl`) and pad the tail with NUL bytes so the REPLACED region is
-- exactly as long as the original -- the file's total length, and every ELF
-- section/symbol-table offset that comes after it, does not change.
--
-- Text files (the ICD manifest below) do not need this: they carry no
-- offsets a shorter string could invalidate, so install() rewrites that one
-- with a plain `io.writefile` instead. This function is for `libpocl.so`
-- only, and only because it is not text.
--
-- Returns `true, n` (n = replacements made, 0 if `old_prefix` is not present
-- at all -- not an error, the caller tries the next candidate) or `false,
-- message` if a match was found but the new path is too long to fit.
local function _rewrite_prefix_in_binary(file, old_prefix, new_prefix)
    local f = io.open(file, "rb")
    if not f then return false, "cannot open " .. file end
    local data = f:read("*a")
    f:close()
    if not data then return false, "cannot read " .. file end

    local out, pos, n = {}, 1, 0
    while true do
        local s, e = data:find(old_prefix, pos, true)
        if not s then break end
        local term = data:find("\0", e + 1, true)
        if not term then break end
        local suffix = data:sub(e + 1, term - 1)
        local pad = (term - s + 1) - #new_prefix - #suffix
        if pad < 0 then
            return false, "payload path is longer than the placeholder it replaces"
        end
        table.insert(out, data:sub(pos, s - 1))
        table.insert(out, new_prefix)
        table.insert(out, suffix)
        table.insert(out, string.rep("\0", pad))
        pos = term + 1
        n = n + 1
    end
    if n == 0 then return true, 0 end

    table.insert(out, data:sub(pos))
    local result = table.concat(out)
    if #result ~= #data then
        -- Every branch above preserves length by construction; reaching this
        -- means the arithmetic above is wrong, not that the input is.
        return false, "internal error: patched length does not match the original"
    end
    local w = io.open(file, "wb")
    if not w then return false, "cannot reopen " .. file .. " for writing" end
    w:write(result)
    w:close()
    return true, n
end

-- Try every known build's placeholder against FILE and apply whichever one
-- is actually present in it. Returns the replacement count (0 if none of the
-- known placeholders occur in the file at all) or `nil, message` on error.
local function _rewrite_conda_placeholder(file, new_prefix)
    for _, old_prefix in ipairs(CONDA_PLACEHOLDERS) do
        local ok, n = _rewrite_prefix_in_binary(file, old_prefix, new_prefix)
        if not ok then return nil, n end
        if n > 0 then return n end
    end
    return 0
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- The tarball's top-level directory carries the version, and moving the
    -- wrong name leaves the download cache as the payload while install()
    -- still reports success -- a package that installs cleanly and has no
    -- `lib/`.
    local top = "pocl-" .. pkginfo.version()
    if not os.isdir(top) then
        log.error("pocl: expected %s in the extracted archive", top)
        return false
    end
    os.mv(top, dir)

    -- `lib/libpocl.so` is a symlink to the real, versioned `.so`; writing
    -- through it (open, truncate-in-place, write) follows the link and
    -- leaves the symlink itself untouched, so this never needs to know the
    -- exact soname suffix a given release ships.
    local libpocl = path.join(dir, "lib/libpocl.so")
    if not os.isfile(libpocl) then
        log.error("pocl: no lib/libpocl.so in the payload")
        return false
    end
    local n, err = _rewrite_conda_placeholder(libpocl, dir)
    if n == nil then
        log.error("pocl: rewriting libpocl.so's build-time path failed: %s", err)
        return false
    end
    if n == 0 then
        -- Not a survivable degradation: without this, libpocl.so looks for
        -- its kernel bitcode and headers under a build-time directory that
        -- exists on no end-user machine, and `clBuildProgram` fails for
        -- every kernel. Loud rather than an install that "succeeds" and
        -- leaves OpenCL programs unable to compile anything.
        log.error("pocl: no known conda build placeholder found in libpocl.so "
                   .. "-- upstream published a new build; CONDA_PLACEHOLDERS "
                   .. "needs a new entry")
        return false
    end
    log.debug("pocl: rewrote %d build-time path(s) in libpocl.so", n)

    -- The ICD manifest is a single line naming the library, recorded under
    -- conda's "text" prefix mode rather than "binary": no padding, no NUL
    -- bytes, it can simply be replaced outright the way mesa-lavapipe
    -- rewrites its Vulkan manifest's `library_path` field. Written with no
    -- trailing newline, matching the file exactly as pocl-core ships it.
    local icd = path.join(dir, "etc/OpenCL/vendors/pocl.icd")
    if os.isfile(icd) then
        io.writefile(icd, libpocl)
    end

    return os.isfile(libpocl)
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    -- The node every `xvm.files` binding below points at. A binding whose
    -- root the recipe never registers is refused
    -- (`xvm-binding-root-missing`), and the package installs but places
    -- nothing -- so this line is not bookkeeping, it is what makes the ICD
    -- manifest reach the subos.
    xvm.add(package.name)

    -- The manifest into the shared OpenCL vendor directory, and
    -- OCL_ICD_VENDORS so ocl-icd looks there at all.
    --
    -- UNLIKE mesa-lavapipe's Vulkan equivalent, this is NOT additive with
    -- the host: ocl-icd (the loader this payload ships, `lib/libOpenCL.so.1`)
    -- has no `OCL_ICD_FILENAMES`-style list variable -- `strings
    -- lib/libOpenCL.so.1.0.0` on it contains OCL_ICD_VENDORS and
    -- OPENCL_VENDOR_PATH and nowhere contains the string "OCL_ICD_FILENAMES"
    -- at all, so setting that variable (the Khronos OpenCL-ICD-Loader's
    -- mechanism, and what a first draft of this recipe assumed ocl-icd
    -- shared) silently does nothing: measured, a probe with
    -- OCL_ICD_FILENAMES=<payload>/lib/libpocl.so found zero platforms.
    -- OCL_ICD_VENDORS is a single directory that REPLACES the default
    -- `/etc/OpenCL/vendors` scan, not a list that extends it -- so a subos
    -- with this declared active shadows a real GPU's OpenCL ICD there for
    -- any process that resolves `-lOpenCL` to this payload's loader. See
    -- `libs/graphics.lua`'s DISCOVERY table, the OCL_ICD_VENDORS row, for the
    -- full measurement and what closing this gap would take.
    graphics.declare_opencl_icd(dir, "etc/OpenCL/vendors", tag)
    graphics.declare_subos_env(tag, graphics.OPENCL_ICD_ONLY)
    return true
end

function uninstall()
    os.tryrm(pkginfo.install_dir())
    return true
end
