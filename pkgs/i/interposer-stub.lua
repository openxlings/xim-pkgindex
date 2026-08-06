package = {
    spec = "2",

    homepage = "https://github.com/xlings-res/interposer-stub",
    name = "interposer-stub",
    description = "Prebuilt empty ELF stub that elfpatch.host_link_interposer turns into an interposer",

    authors = {"xlings"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/xlings-res/interposer-stub",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"toolchain", "internal"},
    keywords = {"interposer", "elfpatch", "graphics"},

    -- Registered with xvm as a ROOT only. It is not a program and not a
    -- library anyone links against: it is an input to elfpatch, consumed by
    -- ABSOLUTE PATH out of the payload (R6), so it puts nothing in a subos's
    -- bin or lib. The root registration is what makes it visible to
    -- `xlings list`, removable, and refcounted -- a package the user cannot
    -- see is one they cannot uninstall (Spec D1).
    xvm_enable = true,

    xpm = {
        linux = {
            -- Why a package at all: an interposer is produced by patchelf,
            -- and patchelf EDITS objects rather than creating them. There is
            -- no compiler at install time, so the object it starts from has
            -- to be shipped. AD-12 chose an index package over carrying it
            -- inside libxpkg: one per arch, through the normal index / mirror
            -- / checksum flow, versioned independently of the client.
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url_template = "https://github.com/xlings-res/interposer-stub/releases/download/{version}/interposer-stub-{version}-linux-{arch}.tar.gz",
                sha256 = {
                    x86_64  = "1e71ceb215b628e8228a5e00a7e3bdc81ee2a337b6a785c1ff89c15c2d00cc4f",
                    aarch64 = "6f5f0db083b4830c559c131b6f29d17feabf0ca6daf0334a187cf6d14b453be5",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The tarball is `lib/interposer-stub.so` and nothing else. Everything
    -- that makes it an interposer is written later by patchelf, per consumer.
    local dir = pkginfo.install_dir()
    local stub = path.join(dir, "lib", "interposer-stub.so")
    if not os.isfile(stub) then
        raise("interposer-stub: lib/interposer-stub.so is not in the payload "
              .. "at " .. dir .. " -- an interposer built from a missing stub "
              .. "would fail at dlopen with nothing naming this package")
    end
    return true
end

function config()
    -- The root only. No `bindir`, no `type = "lib"`: nothing here belongs in
    -- a subos, and consumers reach the stub through pkginfo by absolute path.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
