-- GLEW -- the OpenGL Extension Wrangler, as its upstream source release.
--
-- WHY A SOURCE PAYLOAD. GLEW is one C file plus its headers:
-- `src/glew.c` compiled with `GLEW_STATIC` beside a program IS the library,
-- and that is how a build program with no build step of its own (an mcpp
-- `build.mcpp` naming the file with `mcpp::source`) consumes it. A
-- HuxerUI ecosystem library's Linux row (Lib-Live2D's Cubism renderer,
-- `find_package(GLEW)` on the CMake path) is the consumer this was added
-- for; a prebuilt `libGLEW` would tie the payload to one glibc and one
-- OpenGL loader, which a source that the consumer compiles does not. The
-- release tarball is host-independent, so the three host tables below
-- carry one url and one sha256.
--
-- MEASURED (2026-09-13): the tarball fetched with curl from the upstream
-- GitHub release -- upstream's own artifact, not a git-archive of the tag
-- (the tag has no generated `src/glew.c`; the release does):
--
--   https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz
--   size 835861, sha256 d4fc8289...
--
-- ARCHIVE LAYOUT (measured with `tar tzf`): sole top-level directory
-- `glew-2.2.0/`, with `include/GL/glew.h` (+ `glxew.h`, `wglew.h`,
-- `eglew.h`), `src/glew.c`, `src/glewinfo.c`, `src/visualinfo.c`, the
-- Makefile tree and `LICENSE.txt`. The install hook renames that directory
-- to `<install_dir>`, unmodified, so a consumer names
-- `<install_dir>/include` and `<install_dir>/src/glew.c`.
--
-- LICENCE. `LICENSE.txt` is the Modified BSD licence, the Mesa 3-D MIT
-- licence and the Khronos MIT-style licence together; all permit
-- redistribution. Tier 1; a xlings-res mirror is a follow-up, not a
-- fabricated `CN` url.
--
-- `package.ci` is not declared: the release tag (`glew-2.2.0`) does not
-- match the version key, and 2.2.0 (2020) is the current upstream release.

package = {
    spec = "2",

    name = "glew",
    description = "GLEW - the OpenGL Extension Wrangler library, as source (glew.c + headers) for a consumer to compile in",
    homepage = "https://glew.sourceforge.net",
    maintainers = {"Nigel Stewart"},
    licenses = {"BSD-3-Clause", "MIT"},
    repo = "https://github.com/nigels-com/glew",
    docs = "https://glew.sourceforge.net/basic.html",

    type = "package",
    -- Source only, so every arch this index serves resolves to the one
    -- download.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib", "opengl"},
    keywords = {"glew", "opengl", "gl", "extension", "loader", "graphics"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2.2.0" },
            ["2.2.0"] = {
                url = { GLOBAL = "https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz" },
                sha256 = "d4fc82893cfb00109578d0a1a2337fb8ca335b3ceccf97b97e5cc7f08e4353e1",
            },
        },
        macosx = {
            ["latest"] = { ref = "2.2.0" },
            ["2.2.0"] = {
                url = { GLOBAL = "https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz" },
                sha256 = "d4fc82893cfb00109578d0a1a2337fb8ca335b3ceccf97b97e5cc7f08e4353e1",
            },
        },
        windows = {
            ["latest"] = { ref = "2.2.0" },
            ["2.2.0"] = {
                url = { GLOBAL = "https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz" },
                sha256 = "d4fc82893cfb00109578d0a1a2337fb8ca335b3ceccf97b97e5cc7f08e4353e1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Idempotent across xim engines (mcpp#232): the payload may already be
    -- in install_dir() or still be the extracted tree in the hook CWD, and
    -- success is claimed only with the two files a consumer names in place.
    local dir = pkginfo.install_dir()
    local header = path.join(dir, "include", "GL", "glew.h")
    local source = path.join(dir, "src", "glew.c")
    if os.isfile(header) and os.isfile(source) then return true end

    local extracted = "glew-" .. pkginfo.version()
    if os.isdir(extracted) then
        os.tryrm(dir)
        os.mv(extracted, dir)
    elseif os.isdir(path.join(dir, extracted)) then
        -- Staged into install_dir with the archive's own top-level directory
        -- kept: lift its contents one level.
        local nested = path.join(dir, extracted)
        for _, entry in ipairs(os.dirs(path.join(nested, "*"))) do
            os.mv(entry, path.join(dir, path.filename(entry)))
        end
        for _, entry in ipairs(os.files(path.join(nested, "*"))) do
            os.mv(entry, path.join(dir, path.filename(entry)))
        end
        os.tryrm(nested)
    end
    return os.isfile(header) and os.isfile(source)
end

function config()
    -- No program to shim: the name is registered so that `xlings` lists the
    -- payload and a build program's `xpkg_dir("xim", "glew")` resolves it.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
