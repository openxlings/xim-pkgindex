-- dosbox-staging: DOSBox Staging, with what runs a DOS program by it (tools/res/build.sh
-- dosbox-staging): the emulator as its project releases it for each system, CWSDPMI (the DPMI
-- host a DJGPP program needs) and dirun.toml, the dirun profile beside them. A runner statement
-- names the package's root:
--
--     dirun --payload {} --profile {pkg:dosbox-staging}/dirun.toml -- <arguments>
--
-- The profile places the program as C:\PROG.EXE, runs it with no display, and reads its output,
-- its standard error (0.83.0-2: through DJGPP's REDIR, which the archive carries; dirun 0.4.0) and
-- its status back from files a launcher writes (the emulator's own status is not the program's).
-- 0.83.0-2's profile is read by dirun 0.4.0 or later (dirun 0.3.2 refuses `stderr-file'); a runner
-- statement pins the two together.
-- GLOBAL is github.com/xlings-res/dosbox-staging; CN is the same bytes at gitcode.com/xlings-res.
package = {
    spec = "2",
    homepage = "https://www.dosbox-staging.org/",
    name = "dosbox-staging",
    description = "DOSBox Staging, the DOS emulator, with CWSDPMI and the dirun profile that runs a DOS program by it with no display",
    maintainers = {"https://github.com/xlings-res/dosbox-staging"},
    licenses = {"GPL-2.0-or-later"},
    repo = "https://github.com/dosbox-staging/dosbox-staging",
    docs = "https://www.dosbox-staging.org/manual/",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"emulator", "runner", "dos"},
    keywords = {"dos", "dosbox", "djgpp", "emulator", "dirun", "runner"},
    programs = {"dosbox"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.83.0-2" },
            ["0.83.0-2"] = {
                -- r2: REDIR beside CWSDPMI; the launcher runs the program through it, so its standard
                -- error is a file of its own (`stderr-file`, read by dirun 0.4.0).
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-linux-x86_64.tar.gz",
                },
                sha256 = { ["x86_64"] = "fcf427ff5004f6c8824e36295bd3f2376e85815413e35490d034a04f48e5bcc7" },
            },
            ["0.83.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-linux-x86_64.tar.gz",
                },
                sha256 = { ["x86_64"] = "8665410c1adf3a8d2d1a23be21a4c644058775398777ff449b0c82508e457468" },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.83.0-2" },
            ["0.83.0-2"] = {
                -- r2: REDIR beside CWSDPMI; the launcher runs the program through it, so its standard
                -- error is a file of its own (`stderr-file`, read by dirun 0.4.0).
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-macosx-universal.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-macosx-universal.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "36b783e7be0783f1080a32ade3539f29e6a44d219a5cf0d1ccfd0e0cd67edaea",
                    ["x86_64"] = "36b783e7be0783f1080a32ade3539f29e6a44d219a5cf0d1ccfd0e0cd67edaea",
                },
            },
            ["0.83.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-macosx-universal.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-macosx-universal.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "b2af99014c109071de28c24baad15d513c55f41d588e6cbdd5fdb81bade1f72f",
                    ["x86_64"] = "b2af99014c109071de28c24baad15d513c55f41d588e6cbdd5fdb81bade1f72f",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.83.0-2" },
            ["0.83.0-2"] = {
                -- r2: REDIR beside CWSDPMI; the launcher runs the program through it, so its standard
                -- error is a file of its own (`stderr-file`, read by dirun 0.4.0).
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-windows-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0-2/dosbox-staging-0.83.0-2-windows-x86_64.tar.gz",
                },
                sha256 = { ["x86_64"] = "33f1f1579ab34d44898576c1cfa5991c2c62d870c80f1ea2aafdcece177b76ce" },
            },
            ["0.83.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-windows-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/dosbox-staging/releases/download/0.83.0/dosbox-staging-0.83.0-windows-x86_64.tar.gz",
                },
                sha256 = { ["x86_64"] = "6f96798686a3c7fd6d801e15f39b76cffe29b66dc69537ddaae6a67f8dd4ce7c" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one directory, dosbox-staging-<version>, is the package.
    local top = path.join(path.directory(pkginfo.install_file()), "dosbox-staging-" .. pkginfo.version())
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isfile(path.join(pkginfo.install_dir(), "dirun.toml"))
end

function config()
    local dir = path.join(pkginfo.install_dir(), "dosbox")
    -- The package name anchors the release (Spec D1); the emulator binds to it, so
    -- `xlings use dosbox-staging@<v>` moves it.
    xvm.add(package.name)
    local opts = { bindir = dir, binding = package.name .. "@" .. pkginfo.version() }
    if os.host() == "windows" then
        opts.alias = "dosbox.exe"
    elseif os.host() == "macosx" then
        opts.bindir = path.join(dir, "DOSBox Staging.app", "Contents", "MacOS")
    end
    xvm.add("dosbox", opts)
    return true
end

function uninstall()
    xvm.remove("dosbox")
    xvm.remove(package.name)
    return true
end
