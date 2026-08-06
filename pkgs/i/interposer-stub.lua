package = {
    spec = "2",

    -- Explicit, because a consumer in the SAME PR names it `xim:`.
    --
    -- `config --add-xpkg` registers a recipe into the local index, and
    -- without a declared namespace it lands under `local:`. CI pre-registers
    -- every changed recipe so that a PR adding a stack can install it, but a
    -- dep written `xim:interposer-stub` does not match a `local:` one:
    -- "package 'xim:interposer-stub@>=0.1' not found", for a file sitting in
    -- the same diff. Declaring the namespace makes the local registration and
    -- the published one the same address.
    namespace = "xim",

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
            -- Per-arch entries, not a `url_template` nested in the version
            -- table: a version entry carries EITHER a bare url/source OR one
            -- sub-table per arch. Nesting `url_template` inside it produced
            -- "resource has neither url nor source" -- a warning, then an
            -- empty payload, and the install hook's own assertion was what
            -- caught it. Per-arch also fails closed on an arch we do not ship.
            ["0.1.0"] = {
                x86_64 = {
                    url = "https://github.com/xlings-res/interposer-stub/releases/download/0.1.0/interposer-stub-0.1.0-linux-x86_64.tar.gz",
                    sha256 = "e6b999ca7bdbccc9508754b2bcb606284cc6562056fb7385e1004070268c286b",
                },
                aarch64 = {
                    url = "https://github.com/xlings-res/interposer-stub/releases/download/0.1.0/interposer-stub-0.1.0-linux-aarch64.tar.gz",
                    sha256 = "2843a2b53267766ec6a45738d3ae41e637ac705b85daf1c6c8462738116734f9",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The tarball is one directory `interposer-stub-<ver>-linux-<arch>/`
    -- holding `lib/interposer-stub.so` and nothing else -- the xlings-res
    -- convention, so the stock move works. Everything that makes it an
    -- interposer is written later by patchelf, per consumer.
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(pkginfo.install_file():replace(".tar.gz", ""), dir)

    local stub = path.join(dir, "lib", "interposer-stub.so")
    if not os.isfile(stub) then
        -- Name what WAS there. "not found" alone cannot tell a bad archive
        -- from an extraction that landed elsewhere, and an interposer built
        -- from a missing stub fails at dlopen with nothing naming this
        -- package.
        local seen = {}
        for _, e in ipairs(os.filedirs(path.join(dir, "*"))) do
            table.insert(seen, path.filename(e))
        end
        raise("interposer-stub: lib/interposer-stub.so is not in the payload at "
              .. dir .. "; found: "
              .. (#seen > 0 and table.concat(seen, ", ") or "<nothing>"))
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
