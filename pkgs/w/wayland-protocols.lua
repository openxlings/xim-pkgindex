package = {
    spec = "2",

    homepage = "https://wayland.freedesktop.org",
    name = "wayland-protocols",
    description = "Wayland protocol extension definitions (build-time)",

    authors = {"Wayland contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/wayland/wayland-protocols",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"wayland-protocols", "graphics", "gl"},

    -- WHAT THIS IS FOR, AND THE TRAP IN IT
    --
    -- mesa asks for it the moment the wayland platform is on:
    --
    --   meson.build:2061  dependency('wayland-protocols', version : '>= 1.38')
    --
    -- and mesa reads exactly one variable from it,
    -- `get_variable(pkgconfig : 'pkgdatadir')`, which it hands to
    -- wayland-scanner to generate C that is compiled into libEGL_mesa and libgbm.
    --
    -- The trap: this package existing is not the same as mesa using it. Its .pc
    -- lives in the payload and config() stages nothing into the subos sysroot, so
    -- pkg-config cannot see it unless a build names it explicitly --
    -- `build-in-subos.sh --deps wayland-protocols` or XLINGS_GFX_PKGCONFIG_EXTRA.
    -- The T5 mesa line in tiers.sh did neither, and a host with
    -- /usr/share/pkgconfig/wayland-protocols.pc satisfies mesa silently. So an
    -- installed, correct, published package can sit unused while the host is
    -- consumed in its place, and nothing reports it.

    xpm = {
        linux = {
            deps = {},
            -- Content is architecture-independent -- XML and one .pc, no object
            -- code. `archs` is x86_64 because that is what this index publishes
            -- for; a second arch should be given this same tarball.
            ["latest"] = { ref = "1.45" },
            -- 1.45 alongside 1.38 rather than replacing it. Protocol XML is
            -- purely additive, so a newer set only offers mesa more interfaces --
            -- but a payload already published cannot be withdrawn, and something
            -- may have been built against 1.38.
            --
            -- 1.45 is what the mesa rebuild wants because it is the version the
            -- HOST offered when mesa 25.0.7.1 was built. Matching it means the
            -- rebuild changes the drivers and not the protocol vintage as well.
            ["1.45"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/wayland-protocols/releases/download/1.45/wayland-protocols-1.45-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/wayland-protocols/releases/download/1.45/wayland-protocols-1.45-linux-x86_64.tar.gz",
                },
                sha256 = "b1d0e8ede6e66a04c39ef113e78ce067ea293d1cd826278004db799d05e40516",
            },
            ["1.38"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/wayland-protocols/releases/download/1.38/wayland-protocols-1.38-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/wayland-protocols/releases/download/1.38/wayland-protocols-1.38-linux-x86_64.tar.gz",
                },
                sha256 = "41df27e9b1ad57d7bbf5ed47eade4f71495ddd132417590c0c39185c5559ac0c",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")

function install()
    -- Found by content, not by a hardcoded name.
    --
    -- This used to be `os.mv("wayland-protocols-1.38", dir)` -- a literal that
    -- silently stops matching the moment a second version exists, and os.mv of a
    -- missing path leaves install() returning true with no payload at all. Same
    -- shape as the mesa bug recorded in pkgs/m/mesa.lua: a package that installed
    -- cleanly and had no content.
    local src = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(src) then
        local base = path.directory(src)
        local found = nil
        for _, d in ipairs(os.dirs(path.join(base, "*"))) do
            if os.isfile(path.join(d, "share", "pkgconfig", "wayland-protocols.pc")) then
                found = d; break
            end
        end
        if not found then
            raise("cannot find the payload root under '" .. base
                  .. "': no extracted directory contains share/pkgconfig/wayland-protocols.pc")
        end
        src = found
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)

    -- One representative file per protocol directory, plus the .pc.
    --
    -- All three directories matter and a subset is worse than an absence: mesa
    -- binds linux-dmabuf-v1 from stable, fifo-v1/commit-timing-v1 from staging,
    -- and older compositors still only offer the unstable spellings. A missing
    -- directory configures fine and then misses an interface at run time, which
    -- reads as a compositor-specific rendering fault rather than a missing file.
    local want = {
        { "share/pkgconfig/wayland-protocols.pc",                            "dependency('wayland-protocols')  meson.build:2061" },
        { "share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",          "stable/ -- window management" },
        { "share/wayland-protocols/stable/linux-dmabuf/linux-dmabuf-v1.xml", "stable/ -- zero-copy buffer sharing, what EGL/gbm need" },
    }
    for _, w in ipairs(want) do
        if not os.isfile(path.join(dir, w[1])) then
            raise("wayland-protocols payload is missing " .. w[1] .. " -- " .. w[2])
        end
    end

    -- Count them, because "the directory exists" is a different claim.
    --
    -- A truncated extraction leaves the tree present and nearly empty, and every
    -- path assertion above still passes.
    --
    -- Counted with os.dirs, which is the only enumerator this sandbox actually
    -- has. `os.files`, `os.exists` and `os.filedirs` are all nil here -- each was
    -- tried and each died as "attempt to call a nil value". pkgs/m/musl-gcc.lua
    -- already recorded the first; pkgs/i/interposer-stub.lua:86 calls the third,
    -- so that error path has never run.
    --
    -- Counting directories is not a workaround for the missing file enumerator --
    -- it is the better measure anyway. Upstream ships one directory per protocol
    -- (stable/xdg-shell/, staging/fifo-v1/, unstable/linux-dmabuf/), and some hold
    -- several versioned .xml files, so directories count PROTOCOLS while files
    -- count revisions.
    --
    -- 1.45 has 53; the floor is set well below so a version bump does not need
    -- this number edited, which is the point of a floor.
    local n = 0
    for _, sub in ipairs({"stable", "staging", "unstable"}) do
        for _, e in ipairs(os.dirs(path.join(dir, "share", "wayland-protocols", sub, "*"))) do
            n = n + 1
        end
    end
    if n < 30 then
        raise("only " .. n .. " protocol entries in the payload; 1.45 has 53 across "
              .. "stable/staging/unstable -- the tarball is truncated or the layout changed")
    end

    log.info("wayland-protocols: " .. n .. " protocols in place")
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
