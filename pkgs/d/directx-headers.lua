package = {
    spec = "1",
    homepage = "https://github.com/microsoft/DirectX-Headers",

    name = "directx-headers",
    description = "D3D12 headers + GUID/format-table archives — build-time input for mesa's d3d12 driver",
    authors = {"Microsoft"},
    licenses = {"MIT"},
    repo = "https://github.com/microsoft/DirectX-Headers",

    type = "package",
    archs = {"x86_64"},
    -- dev, for the same reason llvm-dev is: nothing a user installs loads this.
    -- It exists so that BUILDING mesa with -Dgallium-drivers=...,d3d12 has a
    -- named, versioned input instead of a wrap subproject fetched mid-build.
    status = "dev",
    categories = {"graphics", "d3d12", "build"},
    keywords = {"directx", "d3d12", "mesa", "gallium", "wsl", "build-only"},

    -- No `programs`, and there is nothing to argue about: the payload contains
    -- no executables at all. Headers, two static archives, one .pc file.
    --
    -- config() still calls xvm.add(package.name) as a release anchor -- Spec D1,
    -- and it is what makes `xlings remove directx-headers` resolvable instead of
    -- failing with "removal version is not registered" (openxlings/xlings#503).

    xpm = {
        linux = {
            -- No deps, and that is deliberate rather than an omission.
            --
            -- The payload is headers plus two *static* archives. Nothing here is
            -- loaded, dlopen'd or executed, so there is no runtime closure to
            -- declare -- the CI closure guard scans executables and `*.so*`, and
            -- correctly finds neither.
            --
            -- The archives DO carry unresolved libstdc++ references, which get
            -- satisfied when mesa links them in; that obligation belongs to
            -- mesa's own `gcc-runtime@>=15`, not here. It is also why these were
            -- built with gcc 15.1.0 and not 16: see the build script.
            exports = {
                -- include/ only. There is no lib/ entry because `lib` here holds
                -- `.a` files: putting it on a runtime libdir list would advertise
                -- a load path for something that can never be loaded.
                build = { includedirs = { "include" } },
            },
            ["latest"] = { ref = "1.614.1" },
            -- 1.614.1 is exactly mesa's floor (`version : '>= 1.614.1'`,
            -- meson.build:607). Being ahead of the consumer's requirement buys
            -- nothing and makes the pairing harder to reason about.
            ["1.614.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/directx-headers/releases/download/1.614.1/directx-headers-1.614.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/directx-headers/releases/download/1.614.1/directx-headers-1.614.1-linux-x86_64.tar.gz",
                },
                sha256 = "1aa0097f091ccd75c02a00ceda8abbb3f82afea8c1947c303d2c019efbecb065",
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
        -- Identified by content, not by name: the extraction directory is
        -- shared, so "the only directory there" is not a usable rule.
        local base = path.directory(src)
        local found = nil
        for _, d in ipairs(os.dirs(path.join(base, "*"))) do
            if os.isfile(path.join(d, "share", "pkgconfig", "DirectX-Headers.pc")) then
                found = d; break
            end
        end
        if not found then
            raise("cannot find the payload root under '" .. base
                  .. "': no extracted directory contains share/pkgconfig/DirectX-Headers.pc")
        end
        src = found
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(src, pkginfo.install_dir())

    -- Assert what mesa will ask for, naming the line that asks.
    --
    -- A missing member here is otherwise silent: mesa reports
    -- `Run-time dependency DirectX-Headers found: NO` and then evaluates its
    -- `fallback:` wrap, which reaches the network -- so the symptom is a build
    -- that downloads something, not a build that fails.
    local want = {
        { "share/pkgconfig/DirectX-Headers.pc", "dependency('DirectX-Headers')     meson.build:606" },
        { "share/pkgconfig/directx-headers.pc", "dependency('directx-headers')     meson.build:604" },
        { "lib/libd3dx12-format-properties.a",  "Libs: -ld3dx12-format-properties" },
        { "lib/libDirectX-Guids.a",             "Libs: -lDirectX-Guids" },
        { "include/directx/d3d12.h",            "Cflags: -I${includedir}/directx" },
        -- The Windows-type stubs. Without these d3d12.h has no GUID/HRESULT on
        -- Linux and the failure appears deep inside mesa's own sources.
        { "include/wsl/stubs/unknwn.h",         "Cflags: -I${includedir}/wsl/stubs" },
    }
    for _, w in ipairs(want) do
        if not os.isfile(path.join(pkginfo.install_dir(), w[1])) then
            raise("directx-headers payload is missing " .. w[1] .. " -- " .. w[2])
        end
    end

    -- No relocation hook, and that is a property of the payload rather than an
    -- oversight. The .pc expresses its prefix as `${pcfiledir}/../..`, which
    -- pkg-config expands against wherever the file was FOUND -- so the paths are
    -- correct at any install prefix without anything rewriting them. Compare
    -- llvm-dev, which must patch libclc.pc because that file comes from someone
    -- else's build and hardcodes absolute paths.
    log.info("directx-headers: build-time inputs in place (d3d12 headers, 2 archives, pkg-config)")
    log.warn("directx-headers is a BUILD-time package: static archives and headers, "
             .. "no shared objects. It must not appear in a shipped payload's runtime closure.")
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
