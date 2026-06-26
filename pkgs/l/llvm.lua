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
import("xim.libxpkg.system")
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

local function collect_bin_apps(bindir)
    local apps = {}
    local cmd
    if os.host() == "windows" then
        cmd = 'dir /b "' .. bindir .. '" 2>nul'
    else
        cmd = 'ls -1 "' .. bindir .. '" 2>/dev/null'
    end
    local f = io.popen(cmd)
    if f then
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
    end
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
        __install_linux_cfg()
    elseif os.host() == "macosx" then
        __install_macosx_cfg()
    end

    return true
end

function __install_linux_cfg()
    local install_dir = pkginfo.install_dir()
    local bindir = path.join(install_dir, "bin")
    local cxxinc = path.join(install_dir, "include", "c++", "v1")
    local cxxinc_triple = path.join(install_dir, "include", "x86_64-unknown-linux-gnu", "c++", "v1")
    local libcxx_dir = path.join(install_dir, "lib", "x86_64-unknown-linux-gnu")

    local sysroot_dir = system.subos_sysrootdir()

    -- Common flags: use bundled lld, compiler-rt, libunwind (no GCC dependency)
    local common_flags = "-fuse-ld=lld\n"
        .. "--rtlib=compiler-rt\n"
        .. "--unwindlib=libunwind\n"

    -- clang.cfg: C compiler config
    local clang_cfg = common_flags
    -- clang++.cfg: C++ compiler config (use bundled libc++)
    local clangxx_cfg = common_flags
        .. "-nostdinc++\n"
        .. "-stdlib=libc++\n"
        .. "-isystem " .. cxxinc .. "\n"
        .. "-isystem " .. cxxinc_triple .. "\n"
        .. "-L" .. libcxx_dir .. "\n"
        .. "-Wl,-rpath," .. libcxx_dir .. "\n"

    if sysroot_dir and sysroot_dir ~= "" then
        local sysroot_lib = path.join(sysroot_dir, "lib")
        local dynamic_linker = path.join(sysroot_lib, "ld-linux-x86-64.so.2")
        local sysroot_flags = "--sysroot=" .. sysroot_dir .. "\n"
            .. "-Wl,--dynamic-linker=" .. dynamic_linker .. "\n"
            .. "-Wl,--enable-new-dtags,-rpath," .. sysroot_lib .. "\n"
            .. "-Wl,-rpath-link," .. sysroot_lib .. "\n"
        clang_cfg = sysroot_flags .. clang_cfg
        clangxx_cfg = sysroot_flags .. clangxx_cfg
    else
        log.warn("subos sysroot not detected; clang will use system sysroot")
    end

    io.writefile(path.join(bindir, "clang.cfg"), clang_cfg)
    io.writefile(path.join(bindir, "clang-20.cfg"), clang_cfg)
    io.writefile(path.join(bindir, "clang++.cfg"), clangxx_cfg)
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

    local clang_cfg = ""
    local clangxx_cfg = "-isystem" .. cxxinc .. "\n"

    if sdkroot and sdkroot ~= "" then
        clang_cfg = "--sysroot=" .. sdkroot .. "\n"
        clangxx_cfg = "--sysroot=" .. sdkroot .. "\n" .. clangxx_cfg
    else
        log.warn("macOS SDK path not detected; clang may need manual --sysroot")
    end

    io.writefile(path.join(pkginfo.install_dir(), "bin", "clang.cfg"), clang_cfg)
    io.writefile(path.join(pkginfo.install_dir(), "bin", "clang-20.cfg"), clang_cfg)
    io.writefile(path.join(pkginfo.install_dir(), "bin", "clang++.cfg"), clangxx_cfg)
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding = package.name .. "@" .. pkginfo.version()
    local related_apps = collect_bin_apps(bindir)

    xvm.add(package.name)

    for _, app in ipairs(related_apps) do
        xvm.add(app, {
            bindir = bindir,
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
        xvm.remove(app)
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
