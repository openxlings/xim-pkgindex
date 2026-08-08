package = {
    spec = "1",
    homepage = "https://llvm.org",

    name = "llvm-dev",
    description = "LLVM build-time inputs for mesa: clang-cpp + SPIRV-LLVM-Translator + libclc",
    authors = {"LLVM Project", "KhronosGroup"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",

    type = "package",
    archs = {"x86_64"},
    -- dev, deliberately. Nothing a user installs should need this: it exists so
    -- that BUILDING mesa has reproducible inputs instead of borrowed host ones.
    status = "dev",
    categories = {"toolchain", "llvm", "build"},
    keywords = {"llvm", "clang", "libclc", "spirv", "mesa", "build-only"},

    -- No `programs` and no `xvm_enable`, exactly as libllvm does it — and that
    -- omission is the important line in this file.
    --
    -- The payload ships bin/clang, bin/llvm-config, bin/llvm-spirv and ~100
    -- more. Declaring any of them would collide: `llvm` and `llvm-tools`
    -- already own `clang` and `llvm-config`, and `programs` asserts EXCLUSIVE
    -- ownership -- two packages claiming one shim name is exactly what the
    -- orphan-shim audit exists to catch. Consumers reach these tools by payload
    -- path, which is how build-in-subos.sh already invokes build tools.
    --
    -- config() still registers package.name as a release anchor; see the note
    -- there for why that is required even with no program to shim.

    xpm = {
        linux = {
            -- gcc-runtime, and this is the promised payoff of the #560 fix.
            --
            -- 20.1.7 had to declare the whole `xim:gcc@16.1.0` toolchain, because
            -- that payload was compiled by gcc 16 (its libstdc++ ABI was 16's)
            -- and gcc 15.1.0 could not build LLVM here at all -- its frozen
            -- include-fixed/pthread.h shadowed the sysroot and libstdc++'s own
            -- <ext/concurrence.h> stopped compiling.
            --
            -- pkgs/g/gcc.lua now prunes that header, so 20.1.7.1 is built by gcc
            -- 15.1.0 and the dep is the runtime libraries alone. Measured on the
            -- payload rather than assumed:
            --
            --   objdump -p lib/libLLVM.so | grep GLIBCXX_  ->  max 3.4.30
            --
            -- which gcc-runtime 15.1.0 satisfies comfortably. A floor, not a pin:
            -- libstdc++ is backward compatible, so a newer runtime also serves.
            deps = { "xim:gcc-runtime@>=15", "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "20.1.7.1" },
            -- 20.1.7.1: upstream llvm-project is 20.1.7, the fourth component is
            -- ours. It is a different payload, not a rebuild of the same thing:
            --
            --   20.1.7    X86;SPIRV,        built by gcc 16.1.0
            --   20.1.7.1  X86;AMDGPU;SPIRV, built by gcc 15.1.0
            --
            -- AMDGPU is the load-bearing addition. 20.1.7 was built on the theory
            -- that AMDGPU "is libllvm's axis" -- but the libllvm payload is a
            -- lib/ directory with no headers, no LLVMConfig.cmake and no
            -- llvm-config, so meson's two LLVM detection methods can never find
            -- it. libllvm cannot be a BUILD input at all.
            --
            -- So mesa's configure walked past it and reported
            -- `llvm-config found: YES (/usr/bin/llvm-config) 18.1.3` -- the
            -- HOST's LLVM 18, while this index ships libllvm 20.1.7. A libgallium
            -- linked that way needs libLLVM.so.18.1, which does not exist here,
            -- so the payload could not have loaded.
            --
            -- 20.1.7 is REPLACED here, not kept alongside, and that is a
            -- limitation of the recipe rather than a judgement about the payload.
            --
            -- `deps` is declared per PLATFORM, not per version. 20.1.7 was built
            -- by gcc 16 and genuinely needs gcc 16's libstdc++; 20.1.7.1 needs
            -- only gcc-runtime@>=15. One `deps` list cannot be true of both, and
            -- offering a version whose declared deps are wrong is worse than not
            -- offering it -- it resolves, installs, and fails at load on a
            -- GLIBCXX symbol.
            --
            -- The published asset is untouched and still downloadable; anything
            -- that pinned it keeps working. Only this index stops advertising it.
            ["20.1.7.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/llvm-dev/releases/download/20.1.7.1/llvm-dev-20.1.7.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/llvm-dev/releases/download/20.1.7.1/llvm-dev-20.1.7.1-linux-x86_64.tar.gz",
                },
                sha256 = "5a00dd63168c7520d972f142dabf3f3ae79edc38f58a3f4740999e9264c3a99e",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.selfcontain")

function install()
    local src = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(src) then
        -- Identified by content, not by name: the extraction directory is
        -- shared, so "the only directory there" is not a usable rule. What
        -- makes a directory this payload is that it holds the library mesa
        -- actually asks for.
        local base = path.directory(src)
        local found = nil
        for _, d in ipairs(os.dirs(path.join(base, "*"))) do
            if os.isfile(path.join(d, "lib", "libclang-cpp.so")) then found = d; break end
        end
        if not found then
            raise("cannot find the payload root under '" .. base
                  .. "': no extracted directory contains lib/libclang-cpp.so")
        end
        src = found
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(src, pkginfo.install_dir())

    __relocate_pc()
    selfcontain.seal(pkginfo.install_dir())

    -- Assert the three things mesa will ask for, by the name it asks for them.
    --
    -- A missing one here is silent otherwise: mesa's meson reports
    -- `Dependency libclc found: NO` or falls through to looking for a wrap
    -- subproject, and the error names mesa rather than this package.
    local want = {
        { "lib/libclang-cpp.so",        "cpp.find_library('clang-cpp')  meson.build:1900" },
        { "lib/libLLVMSPIRVLib.so",     "dependency('LLVMSPIRVLib')     meson.build:1882" },
        { "share/pkgconfig/libclc.pc",  "dependency('libclc')           meson.build:850"  },
    }
    for _, w in ipairs(want) do
        if not os.isfile(path.join(pkginfo.install_dir(), w[1])) then
            raise("llvm-dev payload is missing " .. w[1] .. " -- " .. w[2])
        end
    end

    log.info("llvm-dev: build-time inputs in place (clang-cpp, LLVMSPIRVLib, libclc)")
    log.warn("llvm-dev is a BUILD-time package. It registers no programs; reach "
             .. "its tools by payload path. It must not appear in a shipped "
             .. "payload's runtime closure.")
    return true
end

-- A release anchor, not a program.
--
-- xvm.add(package.name) with no bindir registers the NAME and its version
-- without creating a shim -- the same thing libllvm and glibc do, and what
-- doctor reports as "release anchor: registers no program of its own". It is
-- required by Spec D1, and it is also what makes `xlings remove llvm-dev`
-- resolvable instead of failing with "removal version is not registered"
-- (openxlings/xlings#503).
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

-- private

-- libclc.pc carries the absolute paths of the machine that built it.
--
-- pkg-config hands `includedir` and `libexecdir` straight to mesa, and mesa
-- passes libexecdir to its own build as the place to find
-- `spirv-mesa3d-.spv`. Left alone, the paths point at the builder's
-- /tmp/.../gfxwork/dist tree, which exists nowhere -- and the failure is a
-- missing bitcode file reported by mesa, three layers from the cause.
--
-- Rewritten by hand rather than through elfpatch.relocate_build_paths: that
-- helper anchors on a marker inside a payload it can enumerate as ELF, and this
-- is a text file whose prefix is simply whatever the build directory was. The
-- pkg-config prefix convention gives us a cleaner fix anyway -- make the paths
-- relative to the file's own location.
function __relocate_pc()
    local pc = path.join(pkginfo.install_dir(), "share", "pkgconfig", "libclc.pc")
    if not os.isfile(pc) then
        log.warn("no libclc.pc in the payload; mesa's dependency('libclc') will not resolve")
        return
    end

    local dir = pkginfo.install_dir()
    local content = io.readfile(pc)
    if not content or content == "" then
        raise("libclc.pc is empty")
    end

    -- Both keys, anchored at line start so a path appearing inside Cflags is
    -- not rewritten twice.
    --
    -- The leading newline is a deliberate trick: `\n<key>=` is the only anchor
    -- that cannot match mid-line, but it would then miss a key on the FIRST
    -- line. Prepending one newline makes every line uniform, and it comes off
    -- again below. The obvious alternative, `content:startswith(...)`, is not
    -- available here -- string has no such method in the recipe sandbox, and it
    -- failed at install time with "attempt to call a nil value".
    local inc     = path.join(dir, "include")
    local libexec = path.join(dir, "share", "clc")
    local body = "\n" .. content
    body = body:gsub("\nincludedir=[^\n]*", "\nincludedir=" .. inc)
    body = body:gsub("\nlibexecdir=[^\n]*", "\nlibexecdir=" .. libexec)
    io.writefile(pc, body:sub(2))

    -- Assert it, because a gsub that matched nothing writes the file back
    -- unchanged and reports success.
    local after = io.readfile(pc) or ""
    if after:find("gfxwork", 1, true) or not after:find(dir, 1, true) then
        raise("libclc.pc still carries build-machine paths after relocation")
    end
    log.info("libclc.pc relocated to " .. dir)
end
