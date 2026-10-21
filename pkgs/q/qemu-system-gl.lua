package = {
    spec = "2",
    homepage = "https://www.qemu.org/",

    name = "qemu-system-gl",
    description = "qemu-system-x86_64 with OpenGL: virtio-gpu-gl-pci through virglrenderer and the egl-headless display -- a Luban machine's 3D on this computer's GPU",

    licenses = {"GPL-2.0-only", "MIT"},
    repo = "https://gitlab.com/qemu-project/qemu",
    docs = "https://www.qemu.org/docs/master/system/devices/virtio-gpu.html",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"emulator", "virtualization"},
    keywords = {"qemu", "virgl", "virtio-gpu", "opengl", "egl", "luban"},

    -- What a Luban machine of a system that may draw with this computer's GPU
    -- (the `gpu` grant, a desktop's) boots with (xlings design 2026-10-20
    -- WuXian §7.5): virtio-gpu-gl-pci gives the machine a GPU, virglrenderer
    -- draws its commands here, and the egl-headless display does it on this
    -- host's render node -- no window. luban installs it the first time a
    -- machine could use it; without it, or should it not start, the machine
    -- draws in software (xim:qemu-system) and says why.
    --
    -- Built by tools/res/build.sh qemu-system-gl, dynamically linked: EGL and
    -- GBM load the driver of the GPU here, which a static build cannot. Against
    -- Debian 12's glibc, patched onto the index's at install (elfpatch); every
    -- library it links is one of the deps below, except virglrenderer, built
    -- with it and carried in lib/. User networking and 9p as xim:qemu-system;
    -- its firmware in share/qemu, found beside the program.
    --
    -- The GPU's driver comes from xim:graphics -- Mesa (radeonsi, iris,
    -- nouveau, llvmpipe) or the host's NVIDIA userspace through
    -- nvidia-gl-host-link (from 0.1.4 its GBM backend, which egl-headless
    -- needs) --
    -- found through the variables that stack declares in the SubOS, which
    -- luban hands to qemu (the Port's subos_env).
    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.44",
                "xim:gcc-runtime",
                "xim:graphics@>=0.1",
                "xim:mesa@>=25",
                "xim:libglvnd@>=1.7.0.1",
                -- 0.1.4 links NVIDIA's GBM backend, which egl-headless needs on
                -- an NVIDIA render node; the graphics stack brings the newest
                -- (an older one: the machine starts in software and says so).
                -- No floor: the index's install test runs a client that reads
                -- an older snapshot, where 0.1.4 is not.
                "xim:nvidia-gl-host-link@>=0.1",
                "xim:libepoxy@>=1.5",
                "xim:libdrm@>=2.4",
                "xim:glib@>=2.74",
                "xim:pixman@>=0.42",
                "xim:zlib@>=1.2",
            },
            ["latest"] = { ref = "9.2.4" },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/qemu-system-gl/releases/download/9.2.4-r1/qemu-system-gl-9.2.4-r1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/qemu-system-gl/releases/download/9.2.4-r1/qemu-system-gl-9.2.4-r1-linux-x86_64.tar.gz",
                },
                sha256 = "efcf2d061d6c84d82eeb4295ef02d48a999cb74b64cee8d81a3e94d48080769c",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.elfpatch")

function install()
    local dir = pkginfo.install_dir()
    -- The archive's root is its own name: qemu-system-gl-<version>-linux-x86_64/.
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    -- glibc's loader, the deps' libraries and its own virglrenderer.
    elfpatch.set({
        interp_from = "linux-x86_64-glibc",
        extra_rpath = { path.join(dir, "lib") },
    })
    for _, f in ipairs({"bin/qemu-system-x86_64", "lib/libvirglrenderer.so.1",
                        "share/qemu/bios-256k.bin", "share/qemu/edk2-x86_64-code.fd"}) do
        if not os.isfile(path.join(dir, f)) then
            raise("qemu-system-gl payload is missing " .. f)
        end
    end
    return true
end

function config()
    -- No program on PATH: `qemu-system-x86_64` is xim:qemu-system's. luban
    -- runs this one from its payload, with the graphics stack's variables.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
