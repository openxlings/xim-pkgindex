package = {
    spec = "1",

    name = "bun",
    description = "Bun is an all-in-one toolkit for JavaScript and TypeScript apps",
    homepage = "https://bun.sh",
    licenses = {"MIT"},
    repo = "https://github.com/oven-sh/bun",
    docs = "https://bun.sh/docs",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"javascript", "runtime", "tools"},
    keywords = {"bun", "javascript", "runtime", "package-manager"},

    programs = {"bun"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- node is needed at install time only (it also provides npm);
            -- after install the selected bun native binary is self-contained.
            -- glibc is the actual runtime dep. Bun's npm package keeps
            -- @oven/* optional platform payloads, including musl variants;
            -- install() picks the glibc one itself and removes the rest,
            -- because CI scans every ELF in the payload.
            deps = {
                runtime = { "xim:glibc@>=2.39" },
                build   = { "xim:node" },
            },
            ["latest"] = { ref = "1.3.11" },
            -- revision 1: npm's postinstall is not run (xlings#724).
            ["1.3.11"] = { revision = 1 },
        },
        macosx = {
            deps = {
                build = { "xim:node" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        windows = {
            deps = {
                build = { "xim:node" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.elfpatch")

-- On Linux the platform binary is chosen here, not by bun's npm postinstall.
-- That script runs the binary it picks to see that it works, before xlings
-- has rewritten its loader: on a machine without /lib64/ld-linux-x86-64.so.2
-- (the Luban host machine on Windows and macOS, Alpine) it cannot start, and
-- the script's fallback then fails with an unrelated ENOENT (xlings#724).
-- With --ignore-scripts every platform package is installed and
-- bin/bun.exe is a placeholder; the glibc one is put there -- xlings binds
-- the payload to its own glibc whatever the host's libc is -- the plain
-- x64 build where the CPU has AVX2, the baseline build otherwise, as the
-- postinstall chooses.
local function linux_platform_binary_(modules)
    local oven = path.join(modules, "@oven")
    local aarch64 = path.join(oven, "bun-linux-aarch64", "bin", "bun")
    if os.isfile(aarch64) then return aarch64 end
    local cpuinfo = io.readfile("/proc/cpuinfo") or ""
    local avx2 = cpuinfo:find("[ \t]avx2[ \t\n]") ~= nil
    local plain = path.join(oven, "bun-linux-x64", "bin", "bun")
    local baseline = path.join(oven, "bun-linux-x64-baseline", "bin", "bun")
    if avx2 and os.isfile(plain) then return plain end
    if os.isfile(baseline) then return baseline end
    return nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local linux = is_host("linux")
    local npm_install = string.format(
        [[npm install --prefix "%s" --no-fund --no-audit%s "bun@%s"]],
        pkginfo.install_dir(),
        linux and " --ignore-scripts" or "",
        pkginfo.version()
    )
    os.exec(npm_install)

    local modules = path.join(pkginfo.install_dir(), "node_modules")
    local selected = path.join(modules, "bun", "bin", "bun.exe")
    if linux then
        local binary = linux_platform_binary_(modules)
        if not binary then
            log.error("bun: no glibc platform package under %s", path.join(modules, "@oven"))
            return false
        end
        os.tryrm(selected)
        os.cp(binary, selected)
        os.exec(string.format([[chmod 755 "%s"]], selected))
        -- bunx is the same program by another name, as the postinstall links it.
        local bunx = path.join(modules, "bun", "bin", "bunx.exe")
        os.tryrm(bunx)
        os.exec(string.format([[ln -s bun.exe "%s"]], bunx))
        -- aarch64: the automatic pass writes the interpreter AND an RPATH, and
        -- the RPATH is what this binary does not survive -- patchelf grows and
        -- moves .dynamic, and the program segfaults before main (measured
        -- under qemu-aarch64 with 1.3.11: interpreter only, it runs; with the
        -- RPATH, in either order, SIGSEGV; xim-pkgindex#1215 saw the same on a
        -- runner). It needs none: the environment's glibc loader finds libc,
        -- libm, libpthread and libdl beside itself. So the interpreter only,
        -- the one the automatic pass would write (the runtime dep's loader).
        if path.filename(path.directory(path.directory(binary))) == "bun-linux-aarch64" then
            local loader
            for _, e in pairs((_RUNTIME and _RUNTIME.deps_exports) or {}) do
                if type(e) == "table" and e.loader and e.loader ~= "" then loader = e.loader; break end
            end
            if not loader then
                log.error("bun: no runtime loader to point %s at", selected)
                return false
            end
            local set = elfpatch.set_interpreter(selected, loader)
            if set.failed > 0 or set.patched == 0 then
                log.error("bun: %s could not be pointed at %s", selected, loader)
                return false
            end
            elfpatch.skip()
        end
    end
    if not os.isfile(selected) then
        return false
    end
    os.tryrm(path.join(modules, "@oven"))
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "node_modules", ".bin")
    local alias = "bun"

    if is_host("windows") then
        alias = "bun.cmd"
    end

    xvm.add("bun", { bindir = bindir, alias = alias })
    return true
end

function uninstall()
    xvm.remove("bun")
    return true
end
