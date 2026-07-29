package = {
    spec = "1",
    homepage = "https://llvm.org",

    name = "llvm",
    description = "LLVM compiler infrastructure and toolchain",
    maintainers = {"LLVM Project"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",
    docs = "https://llvm.org/docs/",

    type = "package",
    archs = {"x86_64", "arm64"},
    status = "stable",
    categories = {"compiler", "toolchain", "llvm"},
    keywords = {"llvm", "clang", "lld", "compiler", "linker"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- slim self-contained toolchain carved from the upstream full release
            -- (same as mac/win, via build-llvm-subpkg.sh --pkg llvm). xim:linux-headers
            -- is a thin delegator to scode:linux-headers, so the install-test harness
            -- registers the scode sub-index (see .github/scripts).
            deps = {
                "xim:glibc@2.39",
                "xim:linux-headers@5.11.1",
                "xim:zlib@1.3.1",
                "xim:libxml2@2.13.5",
                -- clang-22 links libstdc++.so.6 dynamically; clang-20 carried a
                -- static C++ runtime and needed nothing. Nothing else in this
                -- dep list ships libstdc++, so without this the 22.1.8 clang
                -- cannot start at all on a machine that has no system
                -- libstdc++ -- which is every clean machine. It has to be a
                -- declared dep rather than a later `xlings install
                -- gcc-runtime`: the RPATH is baked at llvm install time, so a
                -- runtime that arrives afterwards is invisible to the loader.
                "xim:gcc-runtime@15.1.0",
            },
            ["latest"] = { ref = "22.1.8" },
            ["20.1.7"] = "XLINGS_RES",
            ["22.1.8"] = "XLINGS_RES",
        },
        -- macOS ships a slim, self-contained toolchain carved from the upstream
        -- full release (the 1.4GB upstream monolith is no longer mirrored):
        -- clang/lld/binutils + compiler-rt + libc++ (headers/libs + share/libc++
        -- std modules), with the static .a libs, lldb and clang extra tools
        -- dropped. Built via .agents/tools/build-llvm-subpkg.sh (--pkg llvm).
        macosx = {
            ["latest"] = { ref = "22.1.8" },
            ["20.1.7"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/llvm/releases/download/20.1.7/llvm-20.1.7-macosx-arm64.tar.xz",
                    CN = "https://gitcode.com/xlings-res/llvm/releases/download/20.1.7/llvm-20.1.7-macosx-arm64.tar.xz",
                },
                sha256 = nil,
            },
            ["22.1.8"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/llvm/releases/download/22.1.8/llvm-22.1.8-macosx-arm64.tar.xz",
                    CN = "https://gitcode.com/xlings-res/llvm/releases/download/22.1.8/llvm-22.1.8-macosx-arm64.tar.xz",
                },
                sha256 = nil,
            },
        },
        windows = {
            ["latest"] = { ref = "22.1.8" },
            ["20.1.7"] = "XLINGS_RES",
            ["22.1.8"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local alias_apps = {
    {name = "cc", alias = "clang"},
    {name = "c++", alias = "clang++"},
    {name = "ar", alias = "llvm-ar"},
    {name = "ranlib", alias = "llvm-ranlib"},
    {name = "strip", alias = "llvm-strip"},
    {name = "nm", alias = "llvm-nm"},
}

local alias_apps_windows = {
    {name = "cc", alias = "clang.exe"},
    {name = "c++", alias = "clang++.exe"},
    {name = "cl", alias = "clang-cl.exe"},
    {name = "link", alias = "lld-link.exe"},
    {name = "ar", alias = "llvm-ar.exe"},
    {name = "ranlib", alias = "llvm-ranlib.exe"},
    {name = "strip", alias = "llvm-strip.exe"},
    {name = "nm", alias = "llvm-nm.exe"},
    {name = "lib", alias = "llvm-lib.exe"},
    {name = "rc", alias = "llvm-rc.exe"},
}

local function is_registerable_bin(pathname)
    local name = path.filename(pathname)
    if name == nil or name == "" then
        return false
    end
    if name:sub(-4) == ".cfg" then
        return false
    end
    -- On Windows, skip .dll files (only register .exe)
    if os.host() == "windows" and name:sub(-4) == ".dll" then
        return false
    end
    return os.isfile(pathname)
end

-- Split a bin/ filename into the name to register and the alias to point at.
-- Returns (name, alias) where alias is nil when the two are the same, so
-- non-Windows registration is byte-for-byte what it was before.
local function program_target_name(filename)
    if os.host() == "windows" and filename:sub(-4):lower() == ".exe" then
        return filename:sub(1, -5), filename
    end
    return filename, nil
end

local function collect_bin_apps(bindir)
    local apps = {}
    local cmd
    if os.host() == "windows" then
        -- Backslashes are mandatory here. `dir` is a cmd.exe builtin and
        -- treats "/" as its switch introducer, while libxpkg's path.join
        -- always joins with "/" regardless of host -- so the bindir handed in
        -- looks like `C:\...\xim-x-llvm\22.1.8/bin` and cmd lists nothing.
        -- That is how a full LLVM install ended up registering zero programs
        -- on Windows while clang.exe sat on disk the whole time.
        cmd = 'dir /b "' .. bindir:gsub("/", "\\") .. '" 2>nul'
    else
        cmd = 'ls -1 "' .. bindir .. '" 2>/dev/null'
    end
    local f = io.popen(cmd)
    if not f then
        log.error("llvm: cannot list bin dir (io.popen failed): " .. bindir)
        return apps
    end
    for name in f:lines() do
        local clean = name:gsub("[\r\n]+$", "")
        if clean ~= "" then
            local filepath = path.join(bindir, clean)
            if is_registerable_bin(filepath) then
                table.insert(apps, clean)
            end
        end
    end
    f:close()
    table.sort(apps)
    return apps
end

function install()
    -- The inner directory naming convention per platform:
    --   linux:   llvm-<version>-linux-x86_64
    --   macosx:  derived from filename
    --   windows: llvm-<version>-windows-x86_64
    local llvmdir = "llvm-" .. pkginfo.version() .. "-linux-x86_64"
    if os.host() == "macosx" then
        llvmdir = pkginfo.install_file()
            :replace(".tar.xz", "")
            :replace(".tar.gz", "")
            :replace(".zip", "")
    elseif os.host() == "windows" then
        llvmdir = "llvm-" .. pkginfo.version() .. "-windows-x86_64"
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(llvmdir, pkginfo.install_dir())

    if os.host() == "linux" then
        if not __install_linux_cfg() then
            return false
        end
    elseif os.host() == "macosx" then
        __install_macosx_cfg()
    end

    return true
end

-- Locate the glibc payload runtime that this package's own `deps` declare
-- (xim:glibc). Returns lib_dir, loader_path — or nil when absent.
--
-- Resolution goes through pkginfo.dep_install_dir (store scan with
-- namespace matching + xvm fallback) instead of hand-derived directory
-- layout assumptions. The loader NAME is discovered from the payload
-- contents (any `ld-*.so*`), mirroring glibc.lua's `exports.runtime.loader`
-- declaration, so nothing here hardcodes an architecture.
function __find_glibc_runtime()
    local glibc_dir = pkginfo.dep_install_dir("glibc")
    if not glibc_dir then return nil, nil end

    for _, libname in ipairs({"lib64", "lib"}) do
        local libdir = path.join(glibc_dir, libname)
        local g = io.popen('ls -1 "' .. libdir .. '" 2>/dev/null')
        if g then
            for line in g:lines() do
                local name = line:gsub("[\r\n]+$", "")
                if name:match("^ld%-") and name:find(".so", 1, true) then
                    g:close()
                    return libdir, path.join(libdir, name)
                end
            end
            g:close()
        end
    end
    return nil, nil
end

-- Locate the linux-headers payload's include dir (this package's own dep).
-- xim:linux-headers is a thin delegator to scode:linux-headers, so the
-- xim-namespaced store entry can be a metadata-only husk — require the
-- actual payload marker (include/linux/limits.h) and fall back to the
-- scode namespace explicitly. Returns nil when absent (warn-level: the
-- cfg then omits the kernel-header line; compiles that need <linux/*.h>
-- surface a clear missing-header error instead of a broken install).
function __find_linux_headers_include()
    for _, name in ipairs({"linux-headers", "scode:linux-headers"}) do
        local dir = pkginfo.dep_install_dir(name)
        if dir and os.isfile(path.join(dir, "include", "linux", "limits.h")) then
            return path.join(dir, "include")
        end
    end
    return nil
end

-- Detect the target triple from the payload layout (lib/<triple>).
function __detect_triple(install_dir)
    local f = io.popen('ls -1 "' .. path.join(install_dir, "lib") .. '" 2>/dev/null')
    if f then
        for line in f:lines() do
            local name = line:gsub("[\r\n]+$", "")
            if name:find("-linux-", 1, true) then
                f:close()
                return name
            end
        end
        f:close()
    end
    return nil
end

-- Deterministic, hermetic cfg: generated from the package's OWN deps (the
-- glibc payload), never from whatever environment (subos, host sysroot)
-- happened to exist at install time — the same package version produces the
-- same cfg on every machine, and a human running the bundled clang++
-- directly gets sandbox CRT discovery (-B: Scrt1.o/crti.o/crtn.o — the
-- driver never consults -L for these), the sandbox loader, and bundled
-- libc++. No silent host fallback: without the glibc payload the install
-- fails loudly instead of writing a cfg that links the host's C runtime.
function __install_linux_cfg()
    local install_dir = pkginfo.install_dir()
    local bindir = path.join(install_dir, "bin")

    local glibc_lib, loader = __find_glibc_runtime()
    if not glibc_lib then
        log.error("glibc payload not found (this package's deps declare xim:glibc);"
            .. " refusing to write a host-dependent clang cfg")
        return false
    end

    local common_flags = "-B" .. glibc_lib .. "\n"
        .. "-L" .. glibc_lib .. "\n"
        .. "-Wl,--dynamic-linker=" .. loader .. "\n"
        .. "-Wl,--enable-new-dtags,-rpath," .. glibc_lib .. "\n"
        .. "-fuse-ld=lld\n"
        .. "--rtlib=compiler-rt\n"
        .. "--unwindlib=libunwind\n"

    -- Header axis (C and C++ drivers alike): the C library and kernel
    -- headers come from the same dep payloads the link axis uses. Without
    -- these a direct `clang hello.c` only works when the HOST happens to
    -- ship /usr/include — i.e. silently non-hermetic, and broken on
    -- header-less machines. Ordering matters for C++: libc++'s headers
    -- must be searched BEFORE the glibc headers (its C-header wrappers
    -- reach libc via #include_next), so these lines are appended AFTER the
    -- libc++ -isystem block below — same ordering mcpp's link model emits.
    local c_hdr_flags = "-isystem "
        .. path.join(path.directory(glibc_lib), "include") .. "\n"
    local linux_inc = __find_linux_headers_include()
    if linux_inc then
        c_hdr_flags = c_hdr_flags .. "-isystem " .. linux_inc .. "\n"
    else
        log.warn("linux-headers payload not found; cfg omits kernel headers"
            .. " (compiles needing <linux/*.h> will report missing headers)")
    end

    local clang_cfg = common_flags .. c_hdr_flags
    local clangxx_cfg = common_flags
        .. "-nostdinc++\n"
        .. "-stdlib=libc++\n"
        .. "-isystem " .. path.join(install_dir, "include", "c++", "v1") .. "\n"

    local triple = __detect_triple(install_dir)
    if triple then
        local cxxinc_triple = path.join(install_dir, "include", triple, "c++", "v1")
        if os.isdir(cxxinc_triple) then
            clangxx_cfg = clangxx_cfg .. "-isystem " .. cxxinc_triple .. "\n"
        end
    end
    clangxx_cfg = clangxx_cfg .. c_hdr_flags
    if triple then
        local libcxx_dir = path.join(install_dir, "lib", triple)
        clangxx_cfg = clangxx_cfg
            .. "-L" .. libcxx_dir .. "\n"
            .. "-Wl,-rpath," .. libcxx_dir .. "\n"
    end

    local major = pkginfo.version():match("^(%d+)")
    io.writefile(path.join(bindir, "clang.cfg"), clang_cfg)
    io.writefile(path.join(bindir, "clang++.cfg"), clangxx_cfg)
    if major then
        io.writefile(path.join(bindir, "clang-" .. major .. ".cfg"), clang_cfg)
    end
    return true
end

function __install_macosx_cfg()
    local cxxinc = path.join(pkginfo.install_dir(), "include", "c++", "v1")
    local sdkroot = nil

    local env_sdkroot = os.getenv("SDKROOT")
    if env_sdkroot and env_sdkroot ~= "" and os.isdir(env_sdkroot) then
        sdkroot = env_sdkroot
    else
        local candidates = {
            "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
        }
        for _, cand in ipairs(candidates) do
            if os.isdir(cand) then
                sdkroot = cand
                break
            end
        end
    end

    -- Link with the bundled ld64.lld, not Apple's ld.
    --
    -- Handing the link to Apple's ld crashes it outright on 22.1.8:
    --
    --   dyld: Symbol not found: __ZdaPv
    --     Referenced from: .../XcodeDefault.xctoolchain/usr/bin/ld
    --     Expected in:     .../xim-x-llvm/22.1.8/lib/libc++.1.0.dylib
    --
    -- The driver puts this toolchain's lib dir on DYLD_LIBRARY_PATH when it
    -- spawns the linker, so ld can pick up libLTO from the toolchain. dyld
    -- overrides by LEAF NAME, so ld's own dependency on
    -- /usr/lib/libc++.1.dylib is then satisfied by OUR libc++.1.dylib -- and
    -- libc++ 22 no longer exports operator delete[], which Apple's ld needs.
    -- The slim build does not even ship libLTO.dylib, so nothing is gained in
    -- exchange.
    --
    -- 20.1.7 is poisoned exactly the same way and survives only because
    -- libc++ 20 still happened to export what ld wanted; this is a latent
    -- failure there, not a 22-only bug. Using our own linker removes the
    -- host-toolchain coupling entirely, which is what a "self-contained
    -- toolchain" was supposed to mean.
    local usr_lld = "-fuse-ld=lld\n"

    local clang_cfg = usr_lld
    local clangxx_cfg = usr_lld .. "-isystem" .. cxxinc .. "\n"

    if sdkroot and sdkroot ~= "" then
        clang_cfg = "--sysroot=" .. sdkroot .. "\n" .. clang_cfg
        clangxx_cfg = "--sysroot=" .. sdkroot .. "\n" .. clangxx_cfg
    else
        log.warn("macOS SDK path not detected; clang may need manual --sysroot")
    end

    -- clang reads <invoked-name>.cfg, so the versioned driver needs its own
    -- copy. The major version has to come from pkginfo: hardcoding "clang-20"
    -- put a clang-20.cfg inside the 22.1.8 install (where the driver is
    -- clang-22), so the sysroot silently did not apply to it.
    local major = pkginfo.version():match("^(%d+)") or ""
    io.writefile(path.join(pkginfo.install_dir(), "bin", "clang.cfg"), clang_cfg)
    if major ~= "" then
        io.writefile(path.join(pkginfo.install_dir(), "bin", "clang-" .. major .. ".cfg"), clang_cfg)
    end
    io.writefile(path.join(pkginfo.install_dir(), "bin", "clang++.cfg"), clangxx_cfg)
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding = package.name .. "@" .. pkginfo.version()
    local related_apps = collect_bin_apps(bindir)

    -- A compiler toolchain that registers no programs is never correct, so
    -- fail instead of reporting a successful install of nothing. Without this
    -- the Windows listing bug above produced `✓ 1 package(s) installed`
    -- followed by `xlings: 'clang' is not installed`, with no error in between.
    if #related_apps == 0 then
        log.error("llvm: no registerable programs found in " .. bindir)
        return false
    end

    xvm.add(package.name)

    for _, app in ipairs(related_apps) do
        -- The registered NAME must not carry the extension: users type
        -- `clang`, and `xlings use` looks the target up by that name.
        -- collect_bin_apps returns real filenames, which on Windows means
        -- `clang.exe` -- registering that verbatim produced a target called
        -- "clang.exe" and left `clang --version` reporting
        -- "'clang' is not installed". The alias carries the filename, exactly
        -- as the hand-written alias_apps_windows table above already does.
        local target, alias = program_target_name(app)
        xvm.add(target, {
            bindir = bindir,
            alias = alias,
            binding = binding,
        })
    end

    local aliases = alias_apps
    if os.host() == "windows" then
        aliases = alias_apps_windows
    end

    for _, app in ipairs(aliases) do
        if os.isfile(path.join(bindir, app.alias)) then
            xvm.add(app.name, {
                bindir = bindir,
                alias = app.alias,
                binding = binding,
            })
        else
            log.warn("skip xvm add alias (not found): " .. app.name .. " -> " .. app.alias)
        end
    end

    -- Register libc++ shared libraries for xvm
    if os.host() == "linux" then
        __config_linux_libs()
    end

    return true
end

function __config_linux_libs()
    local libcxx_dir = path.join(pkginfo.install_dir(), "lib", "x86_64-unknown-linux-gnu")
    local binding = package.name .. "@" .. pkginfo.version()

    local libs = {
        "libc++.so", "libc++.so.1",
        "libc++abi.so", "libc++abi.so.1",
        "libunwind.so", "libunwind.so.1",
        "libatomic.so", "libatomic.so.1",
    }

    for _, lib in ipairs(libs) do
        local libpath = path.join(libcxx_dir, lib)
        if os.isfile(libpath) then
            xvm.add(lib, {
                type = "lib",
                bindir = libcxx_dir,
                filename = lib,
                alias = lib,
                binding = binding,
            })
        end
    end
end

function uninstall()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local related_apps = collect_bin_apps(bindir)

    xvm.remove(package.name)

    for _, app in ipairs(related_apps) do
        -- Must strip exactly as config() did, or removal asks for a target
        -- name ("clang.exe") that was never registered and silently removes
        -- nothing, leaving the real shim behind.
        local target = program_target_name(app)
        xvm.remove(target)
    end

    local aliases = alias_apps
    if os.host() == "windows" then
        aliases = alias_apps_windows
    end

    for _, app in ipairs(aliases) do
        xvm.remove(app.name)
    end

    if os.host() == "linux" then
        local libs = {
            "libc++.so", "libc++.so.1",
            "libc++abi.so", "libc++abi.so.1",
            "libunwind.so", "libunwind.so.1",
            "libatomic.so", "libatomic.so.1",
        }
        for _, lib in ipairs(libs) do
            xvm.remove(lib)
        end
    end

    return true
end
