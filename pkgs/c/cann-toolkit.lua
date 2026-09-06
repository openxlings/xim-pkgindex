-- CANN toolkit -- the Ascend device compiler and the per-SoC simulators.
--
-- WHY THIS PACKAGE EXISTS. An Ascend C kernel is compiled by `ccec` (BiSheng),
-- a compiler mcpp does not drive, from a translation unit the C++ toolchain
-- never sees. That is the island shape every accelerator in this ecosystem
-- has, and it needs the vendor's compiler on the machine. CANN's own operator
-- libraries already split `op_kernel/` from `op_host/`, so the seam is one
-- Ascend already draws.
--
-- WHAT IT CARRIES, both measured on 8.5.0 rather than read from a manual:
--
--   <dir>/cann/<arch>-linux/ccec_compiler/bin/{ccec,bisheng,cce-ld,ld.lld,...}
--       the device compiler. `ccec --version` reports clang 15.0.5.
--   <dir>/cann/<arch>-linux/simulator/<SoC>/lib/libpem_davinci.so
--       38 SoC directories -- Ascend310*, Ascend910*, Ascend610*, BS9SX*,
--       MC61AM21A*, AS31XM1 -- each a functional model of that part.
--
-- The second is why this package is worth having on a machine with no NPU: the
-- toolkit ships the simulators, so a rule package can be verified end to end
-- without hardware. `--install` needs neither root nor the driver.
--
-- NOT RE-HOSTED, AND NO CN MIRROR. The `.run` is fetched from Huawei's own
-- distribution host, which is the shape `cuda-nvcc` uses for the same reason:
-- the licence does not permit redistribution. A CN mirror would be pointless
-- here in any case -- the vendor's host is already in-country.
--
-- `--quiet` ACCEPTS THE EULA, which is what makes an unattended install
-- possible and is stated here because it is the one thing about this recipe a
-- reader should know before running it.
--
-- THE INSTALLER WRITES OUTSIDE ITS INSTALL PATH, and `install()` below
-- contains it. Measured: `~/Ascend/ascend_cann_install.info` (8 KB) and
-- `~/var/log/ascend_seclog/`. Overriding HOME for the duration puts both in a
-- scratch directory and the payload installs identically, so a package manager
-- need not leave records in the user's home.
--
-- THE INSTALL PATH IS BAKED IN. The installer writes ABSOLUTE symlinks --
-- `<dir>/cann -> <dir>/cann-8.5.0`, `<dir>/ascend-toolkit/latest -> <dir>/cann`
-- -- so it has to run with the final store directory as its install path. That
-- is what `pkginfo.install_dir()` is, and it is why this hook does not install
-- to a staging directory and move the result.
package = {
    spec = "1",

    name = "cann-toolkit",
    description = "CANN toolkit: the Ascend device compiler (ccec/BiSheng) and the per-SoC simulators",

    maintainers = {"Huawei"},
    licenses = {"Huawei Ascend Software License Agreement"},
    repo = "https://www.hiascend.com/software/cann",
    docs = "https://www.hiascend.com/document",
    homepage = "https://www.hiascend.com/software/cann",

    type = "package",
    -- Linux only, and that is upstream's shape rather than a gap: the toolkit
    -- is published for linux-x86_64 and linux-aarch64 and for nothing else.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "accelerator", "ascend", "npu"},
    keywords = {"cann", "ascend", "npu", "bisheng", "ccec", "ascendc", "simulator"},

    -- The package name is registered (spec D3 requires it, and `xlings use
    -- cann-toolkit@<ver>` keys off it), and NOTHING ELSE IS. `ccec` and
    -- `bisheng` are deliberately not bare-name programs: a device compiler is
    -- reached by the rule package through `mcpp::xpkg_dir`, which is a path
    -- and not a PATH entry, and putting a shim named `ccec` on every shell of
    -- every machine that installs this is a larger claim than the package
    -- needs to make.
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "8.5.0" },
            ["8.5.0"] = {
                x86_64 = {
                    url = "https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/CANN/CANN%208.5.0/Ascend-cann-toolkit_8.5.0_linux-x86_64.run",
                    sha256 = "2cd6412133f1388761051f94f7f59ce428ba2836335ac37dbfd1b96dc6eca5b9",
                },
                aarch64 = {
                    url = "https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/CANN/CANN%208.5.0/Ascend-cann-toolkit_8.5.0_linux-aarch64.run",
                    sha256 = "bd702440a2b3bf1e0a07d321ed5cb55c181e954a82d0b8edd4b13039b37ef929",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local run = pkginfo.install_file()
    if not run or not os.isfile(run) then
        raise("cann-toolkit: the downloaded installer is missing (install_file = "
              .. tostring(run) .. ")")
    end

    -- THE PAYLOAD IS READ-ONLY AND THAT MAKES IT UNREMOVABLE. The installer
    -- writes directories 0550 and scripts 0500, so a plain `rm -rf` over a
    -- previous install fails on every one of them -- measured, several hundred
    -- `Permission denied` lines and a directory left half-deleted. Restoring
    -- write permission first is what makes reinstall and uninstall work at
    -- all; `|| true` because the directory legitimately does not exist on a
    -- first install.
    system.exec("sh -c \"chmod -R u+w '" .. dir .. "' 2>/dev/null || true\"")
    os.tryrm(dir)
    os.mkdir(dir)

    -- A scratch HOME, so the installer's two records land here and not in the
    -- user's home directory. Removed below; nothing in the payload refers to
    -- it, which was checked by running the toolkit's compiler afterwards.
    local fakehome = path.join(dir, ".install-home")
    os.mkdir(fakehome)

    system.exec("chmod +x " .. run)
    -- `--quiet` accepts the EULA and skips every prompt, which is the only way
    -- an unattended install is possible. `--install-path` is the final store
    -- directory because the installer bakes absolute symlinks (see the header).
    system.exec("env HOME=" .. fakehome .. " " .. run
                .. " --install --install-path=" .. dir .. " --quiet")

    os.tryrm(fakehome)

    -- ASSERTED, NOT ASSUMED, and asserted on the COMPILER rather than on a
    -- directory listing. A toolkit that unpacks and cannot compile is the
    -- failure this package exists to remove, and finding it out here costs one
    -- exec while finding it out from a build costs a whole graph first.
    -- THE ARCH SEGMENT IS READ FROM THE TREE, NOT FROM `os.arch()`, which is
    -- not bound inside an install hook -- `jdk-zulu.lua` records the same
    -- trap, and the failure is a nil-field call that names neither the arch
    -- nor this line. The installer writes exactly one `<arch>-linux`
    -- directory, so trying the two upstream spells is both complete and
    -- self-checking.
    local arch, ccec = nil, nil
    for _, a in ipairs({"x86_64", "aarch64"}) do
        local candidate = path.join(dir, "cann", a .. "-linux",
                                    "ccec_compiler", "bin", "ccec")
        if os.isfile(candidate) then arch, ccec = a, candidate break end
    end
    if not ccec then
        raise("cann-toolkit: no device compiler under " ..
              path.join(dir, "cann") .. " (looked for <arch>-linux/ccec_compiler/bin/ccec)")
    end
    local out = try { function() return os.iorun(ccec .. " --version") end }
    if not out or not out:find("clang version", 1, true) then
        raise("cann-toolkit: the installed device compiler does not run "
              .. "(`--version` said: " .. tostring(out) .. ")")
    end

    -- The simulators are the half that makes this usable without hardware, so
    -- their absence is a failed install rather than a missing extra.
    local sim = path.join(dir, "cann", arch .. "-linux", "simulator")
    if not os.isdir(sim) then
        raise("cann-toolkit: no simulator directory at " .. sim)
    end

    return true
end

function config()
    -- The umbrella node only -- see `xvm_enable` above for why the compilers
    -- are not registered beside it.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    -- Same reason as in `install()`: without this the payload's own 0550
    -- directories make it undeletable, and `xlings remove` leaves a partial
    -- tree that the next install then cannot replace either.
    local dir = pkginfo.install_dir()
    system.exec("sh -c \"chmod -R u+w '" .. dir .. "' 2>/dev/null || true\"")
    os.tryrm(dir)
    return true
end
