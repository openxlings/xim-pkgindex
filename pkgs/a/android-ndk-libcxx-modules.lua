-- The libc++ module sources of an Android NDK release: share/libc++/v1
-- (std.cppm, std.compat.cppm and their std/*.inc, std.compat/*.inc
-- partitions), which `import std;` precompiles.
--
-- WHY IT IS A PACKAGE. Google's Linux and macOS archives of NDK r30 carry these
-- files beside the host's own libc++; the Windows archive does not, because its
-- clang toolchain is built without a host libc++ and the module sources are
-- installed with it (docs/android-ndk-libcxx-modules.md). The sources are not
-- host code: they describe the TARGET's libc++, whose headers
-- (sysroot/usr/include/c++/v1) the Windows archive does ship. Measured on r30:
-- the Linux and Windows archives are the same Pkg.Revision, the same clang
-- revision (AndroidVersion.txt: 21.0.0, r574158c), and their 1665 libc++
-- headers are byte-identical -- so the Linux archive's module sources are the
-- ones the Windows toolchain is missing.
--
-- ONE PAYLOAD FOR EVERY HOST. tools/res/build.sh android-ndk-libcxx-modules
-- <version> takes the files out of the Linux archive unmodified, after
-- checking those facts on both archives; MANIFEST lists each file with its
-- sha256. The derivation also checks that the darwin archive's sources are
-- these files, so one payload is what every host's archive carries or lacks.
-- xim:android-ndk's `windows` entry depends on it and installs the files into
-- its toolchain; the linux and macosx entries use their archives' own copy.
--
-- No `ci`: a new NDK release is assessed with
-- `tools/res/android-ndk/libcxx_modules.py probe <urls>` and built by hand,
-- together with xim:android-ndk's own version entry.
package = {
    spec = "2",
    homepage = "https://developer.android.com/ndk",

    name = "android-ndk-libcxx-modules",
    description = "libc++ module sources (std.cppm, std.compat.cppm) of an Android NDK release, for NDK hosts whose archive omits them",

    maintainers = {"The LLVM Project", "The Android Open Source Project"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/openxlings/xim-pkgindex/tree/main/tools/res/android-ndk",
    docs = "https://github.com/openxlings/xim-pkgindex/blob/main/docs/android-ndk-libcxx-modules.md",

    type = "package",
    -- Data: the same files whichever host reads them.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"toolchain", "cross", "android"},
    keywords = {"android", "ndk", "libc++", "modules", "import-std"},

    xvm_enable = true,

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/android-ndk-libcxx-modules/releases/download/${version}/android-ndk-libcxx-modules-${version}.tar.gz",
            CN = "https://gitcode.com/xlings-res/android-ndk-libcxx-modules/releases/download/${version}/android-ndk-libcxx-modules-${version}.tar.gz",
        },
        linux = {
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = { sha256 = { x86_64 = "3956d41db1d063163fc85e6b0461729478a671a3d9e78e9d7dfd8a158371a7bc", aarch64 = "3956d41db1d063163fc85e6b0461729478a671a3d9e78e9d7dfd8a158371a7bc" } },
        },
        macosx = {
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = { sha256 = "3956d41db1d063163fc85e6b0461729478a671a3d9e78e9d7dfd8a158371a7bc" },
        },
        windows = {
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = { sha256 = "3956d41db1d063163fc85e6b0461729478a671a3d9e78e9d7dfd8a158371a7bc" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    local extracted = path.join(path.directory(pkginfo.install_file()),
                                "android-ndk-libcxx-modules-" .. pkginfo.version())
    if not os.isdir(extracted) then
        raise("android-ndk-libcxx-modules: payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    for _, f in ipairs({"MANIFEST", "share/libc++/v1/std.cppm", "share/libc++/v1/std.compat.cppm"}) do
        if not os.isfile(path.join(dir, f)) then
            raise("android-ndk-libcxx-modules: payload is missing " .. f)
        end
    end
    return true
end

-- Data, not a program: registered as a group so a home knows it has it.
function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
