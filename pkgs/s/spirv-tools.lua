package = {
    spec = "1",
    homepage = "https://github.com/KhronosGroup/SPIRV-Tools",

    name = "spirv-tools",
    description = "SPIRV-Headers + SPIRV-Tools — build-time input for mesa's mesa_clc (iris)",
    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/SPIRV-Tools",

    type = "package",
    archs = {"x86_64"},
    -- dev, like llvm-dev and directx-headers: mesa uses it only inside mesa_clc,
    -- a host tool run while the payload is being BUILT.
    status = "dev",
    categories = {"graphics", "spirv", "build"},
    keywords = {"spirv", "spirv-tools", "spirv-headers", "mesa", "iris", "clc", "build-only"},

    -- No `programs`, though the payload does ship bin/spirv-as, spirv-val,
    -- spirv-opt and friends.
    --
    -- They are kept so the payload can be checked on its own -- the build
    -- assembles and validates a real SPIR-V module rather than listing files --
    -- but declaring them would put user-facing shims on a build-only package, and
    -- `programs` asserts EXCLUSIVE ownership of those names. Consumers reach them
    -- by payload path, which is how build-in-subos.sh already invokes build tools.

    xpm = {
        linux = {
            -- gcc-runtime, not gcc.
            --
            -- The archives are C++ and carry unresolved libstdc++ references, so
            -- whatever links them needs a compatible runtime. Measured on the
            -- payload's own executables rather than assumed:
            --
            --   objdump -p bin/spirv-val | grep GLIBCXX_   ->  well under 3.4.34
            --
            -- Built by gcc 15.1.0 for the same reason directx-headers is: these
            -- end up inside a host tool that also links our LLVM, and mixing
            -- libstdc++ ABIs across that boundary breaks RTTI and exceptions.
            deps = { "xim:gcc-runtime@>=15", "xim:glibc@>=2.38" },
            exports = {
                -- No runtime libdirs: `lib` holds `.a` files only. Advertising a
                -- runtime load path for a static archive would be a claim that
                -- cannot be true.
                build = { includedirs = { "include" } },
            },
            ["latest"] = { ref = "2025.1" },
            -- 2025.1 is the upstream tag. Its own pkg-config reports `2025.1.1`,
            -- which is upstream's business; mesa only asks for `>= 2022.1`
            -- (meson.build:1887) and both forms satisfy it.
            ["2025.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/spirv-tools/releases/download/2025.1/spirv-tools-2025.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/spirv-tools/releases/download/2025.1/spirv-tools-2025.1-linux-x86_64.tar.gz",
                },
                sha256 = "9996bdb6a1753b4106ab9d288996bd83063e8b52855d99b135f876880688adc8",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    local src = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(src) then
        -- By content, not by name: the extraction directory is shared.
        local base = path.directory(src)
        local found = nil
        for _, d in ipairs(os.dirs(path.join(base, "*"))) do
            if os.isfile(path.join(d, "lib", "pkgconfig", "SPIRV-Tools.pc")) then
                found = d; break
            end
        end
        if not found then
            raise("cannot find the payload root under '" .. base
                  .. "': no extracted directory contains lib/pkgconfig/SPIRV-Tools.pc")
        end
        src = found
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)

    -- Assert both halves, naming what each is for.
    --
    -- SPIRV-Headers is the half that is easy to lose: SPIRV-Tools.pc can name it
    -- in `Requires:`, and pkg-config resolves that at QUERY time -- so a payload
    -- missing the headers makes mesa report SPIRV-TOOLS as not found, pointing at
    -- the wrong package entirely.
    local want = {
        { "lib/pkgconfig/SPIRV-Tools.pc",     "dependency('SPIRV-Tools')  meson.build:1887" },
        { "lib/libSPIRV-Tools.a",             "the static library mesa_clc links" },
        { "include/spirv-tools/libspirv.h",   "the C API mesa_clc includes" },
        { "include/spirv/unified1/spirv.h",   "SPIRV-Headers -- pinned by SPIRV-Tools' own DEPS" },
    }
    for _, w in ipairs(want) do
        if not os.isfile(path.join(dir, w[1])) then
            raise("spirv-tools payload is missing " .. w[1] .. " -- " .. w[2])
        end
    end

    -- Static-only, asserted.
    --
    -- Upstream builds `SPIRV-Tools-shared` as its own cmake target, which
    -- -DBUILD_SHARED_LIBS=OFF does not suppress; the build script drops it. If one
    -- ever survives into a payload, a link line could pick it up and libgallium
    -- would gain a DT_NEEDED on a library that -- this being a `dev` package -- is
    -- not in mesa's runtime deps and never installed on a user's machine. The
    -- symptom would be a dlopen failure naming a library nobody declared.
    --
    -- Enumerated with `ls` via os.iorun because the recipe sandbox has no file
    -- lister: os.files, os.exists and os.filedirs are all nil here.
    local out = os.iorun(string.format(
        "sh -c 'ls %s/lib/*.so* 2>/dev/null || true'",
        "'" .. dir:gsub("'", "'\\''") .. "'"))
    local shared = {}
    for _, line in ipairs((out or ""):split("\n", { plain = true })) do
        local f = line:trim()
        if f ~= "" then table.insert(shared, path.filename(f)) end
    end
    if #shared > 0 then
        raise("spirv-tools payload contains shared objects (" .. table.concat(shared, ", ")
              .. "); this package must be static-only so it cannot enter a shipped "
              .. "payload's runtime closure")
    end

    log.info("spirv-tools: build-time inputs in place (static SPIRV-Tools + SPIRV-Headers)")
    log.warn("spirv-tools is a BUILD-time package: static archives only. It must not "
             .. "appear in a shipped payload's runtime closure.")
    return true
end

function config()
    -- Release anchor, no program. Spec D1; also what makes `xlings remove
    -- spirv-tools` resolvable (openxlings/xlings#503).
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
