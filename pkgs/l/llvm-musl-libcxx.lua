package = {
    spec = "2",
    homepage = "https://libcxx.llvm.org/",

    name = "llvm-musl-libcxx",
    description = "musl-targeted libc++ static runtime and std module sources - closes the LLVM-family gap on *-linux-musl",

    maintainers = {"https://github.com/llvm/llvm-project/graphs/contributors"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",
    docs = "https://libcxx.llvm.org/",

    type = "package",
    -- HOST arches: the payload is consumed by a HOST clang cross-compiling to
    -- the musl target of the matching TARGET arch (x86_64 host -> x86_64
    -- target, aarch64 host -> aarch64 target; a cross from either host arch to
    -- either target arch also resolves the matching asset).
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "toolchain", "c++", "llvm", "musl"},
    keywords = {"libc++", "libcxx", "musl", "llvm", "static", "cross"},

    -- No programs: a data payload of headers, archives and module sources.
    xvm_enable = true,

    -- ⭐ WHY THIS PACKAGE EXISTS.
    --
    -- The llvm payload's clang frontend carries no target libc at all, and its
    -- bundled clang.cfg pins the HOST's glibc world. Serving *-linux-musl from
    -- the LLVM family therefore needs three things clang does not ship:
    --   1. libc++ configured FOR the musl target (a host libc++'s __config_site
    --      describes a different ABI and cannot be reused),
    --   2. the std/std.compat module sources precompiled against that libc++
    --      (a std BMI built over the host libc++ is wrong at the PCM level),
    --   3. crt/libgcc/libc -- which musl-gcc already provides, so this package
    --      does NOT duplicate them; the mcpp engine points clang at the
    --      musl-gcc payload via --gcc-toolchain and only the C++ runtime
    --      (libc++/libc++abi/libunwind static archives) comes from here.
    --
    -- Built from llvm-project release/22.x runtimes (LLVM_ENABLE_RUNTIMES =
    -- libcxx;libcxxabi;libunwind) with the clang 22.1.8 payload cross-driving
    -- into each target's musl sysroot. Static-only: the musl story is fully
    -- static ELF, and dynamic libc++ on musl buys nothing this target wants.
    --
    -- Payload layout (consumed by mcpp's llvm-musl branch, PR mcpp#492):
    --   include/c++/v1/        libc++ headers configured for the musl target
    --   lib/libc++.a lib/libc++abi.a lib/libunwind.a
    --   share/libc++/v1/std.cppm share/libc++/v1/std.compat.cppm
    --   share/libc++/v1/std/ share/libc++/v1/std.compat/  export tables
    --
    -- ⚠️ No `ci` block, deliberately: `mirror` would point the mirror at
    -- xlings-res before the asset is migrated there (the URLs below stage on
    -- the contributor fork's releases and maintainers move them to xlings-res,
    -- same handover `libcxx-headers` documents), and `update` would bump
    -- `latest` to a new LLVM release whose artifact does not exist -- this
    -- payload must be REBUILT from a new llvm payload per target arch, which
    -- is a human step with a build recipe, not a re-download.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/llvm-musl-libcxx/releases/download/${version}/llvm-musl-libcxx-${version}-linux-${arch2}.tar.xz",
            CN = "https://gitcode.com/xlings-res/llvm-musl-libcxx/releases/download/${version}/llvm-musl-libcxx-${version}-linux-${arch2}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = {
                url = {
                    -- Staging until the asset lands on xlings-res; the sha256
                    -- pins the bytes either way. See the ci-block note above.
                    GLOBAL = "https://github.com/cloud-teahouse/mcpp/releases/download/llvm-musl-libcxx-22.1.8/llvm-musl-libcxx-22.1.8-linux-x86_64.tar.xz",
                },
                sha256 = {
                    x86_64 = "bdd30f05fc9136f9e582caec727f2c39c195acd29a21e79d1a19e3c170cc381c",
                    aarch64 = "e5bfac3136c69a50dff4511a8220e7022caac1facbe4e2db15c03e363f368548",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("llvm-musl-libcxx payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Assert the three halves a consumer needs; the easiest mistake when
    -- rebuilding this payload from a new llvm release is dropping one.
    if not os.isfile(path.join(dir, "include", "c++", "v1", "algorithm")) then
        raise("llvm-musl-libcxx payload is missing include/c++/v1/algorithm")
    end
    if not os.isfile(path.join(dir, "lib", "libc++.a")) then
        raise("llvm-musl-libcxx payload is missing lib/libc++.a")
    end
    if not os.isfile(path.join(dir, "share", "libc++", "v1", "std.cppm")) then
        raise("llvm-musl-libcxx payload is missing share/libc++/v1/std.cppm")
    end

    return true
end

function config()
    -- Umbrella node only, for the same reason `libcxx-headers` is one: this is
    -- a SECOND copy of the C++ standard library, targeted at musl. Publishing
    -- it into the host sysroot would shadow the host's own libc++ for every
    -- ordinary build. The mcpp engine's llvm-musl branch is the consumer: it
    -- resolves this payload for the target and points -isystem/-L at it.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
