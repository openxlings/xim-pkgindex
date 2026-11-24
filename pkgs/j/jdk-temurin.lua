package = {
    spec = "2",

    -- base info
    name = "jdk-temurin",
    description = "Eclipse Temurin — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin25-binaries",
    docs = "https://adoptium.net/docs",
    authors = {"Eclipse Adoptium"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "temurin", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- WHY THE NAME
    --
    -- The flavor is in the package name (`jdk-temurin`) so other
    -- distributions can coexist as jdk-oracle / jdk-microsoft / jdk-zulu
    -- later; the JDK version lives in the version dimension (25.0.4+7), so
    -- future JDK 26/27 land in this same package. This mirrors how apt
    -- (`openjdk-25-jdk`) / dnf (`java-25-openjdk`) / Arch (`jdk25-openjdk`)
    -- all embed the flavor in the name.
    --
    -- VERSION STRING — the canonical version key carries the OpenJDK build
    -- number (JEP 322: `$FEATURE.$INTERIM.$UPDATE+$BUILD`), matching the
    -- upstream tag `jdk-25.0.4+7`, the Adoptium API semver `25.0.4+7.0.LTS`
    -- and what mise/asdf call this build. But `java --version` prints only
    -- `openjdk 25.0.4` on its first line (the `+7` shows up further down, in
    -- `Temurin-25.0.4+7 (build 25.0.4+7-LTS)`), and `java.version` is plain
    -- `25.0.4` -- so users reasonably type what they see. Hence the
    -- `["25.0.4"] = { ref = "25.0.4+7" }` alias on every platform: both
    -- `xlings install jdk-temurin@25.0.4` and `@25.0.4+7` resolve to the same
    -- resource. Future security updates add their own pair (25.0.5 -> ...).
    --
    -- PROVENANCE — Temurin (Eclipse Adoptium) LTS releases:
    --   * 25.0.4+7    (released 2026-07-29, temurin25-binaries)
    --   * 21.0.13.1+2 (released 2026-11-18, temurin21-binaries)
    --   * 17.0.21.1+2 (released 2026-11-18, temurin17-binaries)
    --   * 11.0.33+10  (released 2026-11-04, temurin11-binaries; selected over
    --                  jdk-11.0.33.1+1 because 11.0.33.1+1 lacks windows x86_64)
    --   * 8.0.512+9   (released 2026-11-04, temurin8-binaries tag jdk8u512-b09;
    --                  selected over partial jdk8u514-b01 which only has linux x64)
    -- Per-arch sha256 values come from api.adoptium.net and GitHub `.sha256.txt`
    -- sidecars, and were re-verified against downloaded archives alongside
    -- top-level directory layout (`jdk-<version>/` for 11+, `jdk8u512-b09/`
    -- for 8, and `<root>/Contents/Home/` on macosx).
    --
    -- LTS SERIES & ALIASES — Each older LTS series exposes both a major
    -- alias (`"21"`, `"17"`, `"11"`, `"8"`) and the plain version printed by
    -- `java -version` / `javac -version` (`"21.0.13.1"`, `"17.0.21.1"`,
    -- `"11.0.33"`, `"8.0.512"`, plus `"8u512b09"` for JDK 8), alongside the
    -- canonical `<version>+<build>` key. `latest` stays pinned to `"25.0.4+7"`
    -- so existing downstream recipes (`gradle`, `kotlin`, `maven`) are
    -- unaffected.
    --
    -- MANUAL MAINTENANCE (no extensions.autoupdate) — Like `jdk-zulu.lua`,
    -- `jdk-corretto.lua`, and `php.lua`, this recipe now manages multiple
    -- independent major LTS series (`25`, `21`, `17`, `11`, `8`) in one file:
    --   * Each major series lives in a separate upstream repository
    --     (`temurin{25,21,17,11,8}-binaries`), and JDK 8 uses `jdk8u...-b...`
    --     tags and has no `macosx aarch64` build.
    --   * `extensions.autoupdate` only tracks a single upstream repo/matrix
    --     and treats every numeric `{ ref = ... }` alias and single-arch JDK 8
    --     backfill as invalid matrix drift, so bumps across these LTS lines
    --     are maintained manually.
    --
    -- RESOURCE SHAPE — Shape B per-arch resource maps, because Adoptium's
    -- release tag and archive filename encode the build number differently:
    --   tag  jdk-25.0.4+7                  (URL-escaped as %2B)
    --   file OpenJDK25U-jdk_..._25.0.4_7.  (build joined with '_')
    --   8    jdk8u512-b09 / ..._8u512b09.
    -- A URL template cannot express all encodings across LTS lines, so each
    -- os/arch URL is explicit.
    --
    -- CN MIRROR —
    --   * 25.0.4+7 uses {GLOBAL, CN} where CN is gitcode.com/xlings-res/jdk-temurin
    --     (tag `25.0.4_7`, avoiding GitCode's `+`-to-space decoding 404).
    --   * 21.0.13.1+2 and 17.0.21.1+2 use {GLOBAL, CN} where CN is
    --     mirrors.tuna.tsinghua.edu.cn/Adoptium/, verified HTTP 200 and
    --     byte-identical SHA256 across all 5 archives (note: TUNA only retains
    --     the latest release per feature line; USTC github-release only has
    --     older 21.0.9+10 / 17.0.9+9.1 and mirrors.ustc.edu.cn/Adoptium/ is 404).
    --   * 11.0.33+10 declares GLOBAL only: TUNA has already rotated linux/x64
    --     and macOS to 11.0.33.1_1 (which lacks windows x64), USTC only keeps
    --     11.0.33.1+1, and GitCode xlings-res only hosts 25.0.4_7.
    --   * 8.0.512+9 uses {GLOBAL, CN} (TUNA) on linux/aarch64, macosx/x86_64,
    --     and windows/x86_64 (verified HTTP 200 and byte-identical SHA256), and
    --     GLOBAL-only on linux/x86_64 because TUNA rotated `8/jdk/x64/linux/`
    --     to `8u514b01` (404 for `8u512b09`) and USTC only keeps `jdk8u514-b01`.
    --     Per repo rules, unverified or 404 CN URLs are never declared.
    --
    -- ARCH COVERAGE — Temurin 25/21/17/11 ship linux + macosx on x86_64/aarch64
    -- and x86_64 only on windows (no windows-aarch64 image for 25/17/11/8).
    -- Temurin 8 (`8.0.512+9`) additionally ships NO `macosx aarch64` (Apple
    -- Silicon) build (`mac` is `x86_64` only). `archs = {x86_64, aarch64}` is
    -- the union; unsupported host/arch pairs fail closed cleanly.
    --
    -- RUNTIME DEPS — deliberately NONE, and the ELF tree says why: a full
    -- readelf sweep of the linux x86_64 build shows the only hard external
    -- DT_NEEDED set is glibc (libc/libdl/libm/libpthread/librt + the
    -- ld-linux INTERP). There is no libstdc++/libgcc_s anywhere in the tree
    -- (HotSpot links them statically), so this package does NOT need
    -- node.lua's `xim:gcc-runtime`. libX11/libXext/libXi/libXrender/libXtst,
    -- libasound and libfreetype appear only in libawt_xawt / libjsound /
    -- libfontmanager / libsplashscreen, which a headless JVM never dlopens.
    -- `bin/java` already carries RPATH `$ORIGIN:$ORIGIN/../lib`, so the tree
    -- is relocatable as shipped. Alpine / distroless support means an
    -- INTERP rewrite across that tree; that is a separate, real-machine
    -- verified change, not something to declare blind here.
    --
    -- That change has now been measured, and it does NOT work yet. Declaring
    -- `xim:glibc` would be enough to trigger it — elfpatch's predicate keys off
    -- the loader glibc exports — and the headless result is perfect: patching a
    -- copy of this payload to our loader with the dependency closure as RPATH
    -- gives a working `java -version`, `javac`, libzip, libnet,
    -- `InetAddress.getByName`, NSS `user.name`, UTF-8 default charset. The
    -- `$ORIGIN` entries are not even missed: 14 libraries in lib/ name
    -- libjvm.so from lib/server/ and resolve it anyway, because libjli has
    -- already loaded it into the global scope by then.
    --
    -- AWT is what breaks, and it breaks hard (verified against an unpatched
    -- control on the same machine, DISPLAY=:1):
    --
    --   unpatched   Toolkit.getDefaultToolkit() -> ok, 2560x1440
    --   patched     UnsatisfiedLinkError: libawt_xawt.so: libX11.so.6:
    --               cannot open shared object file
    --
    -- The reason is general and worth knowing before switching ANY package: our
    -- glibc's ld.so has the build machine's cache path compiled in
    -- (`/home/xlings/.xlings_data/.../etc/ld.so.cache`), which exists on no
    -- machine. On a multiarch distro libX11 lives in /usr/lib/x86_64-linux-gnu
    -- and is reachable ONLY through that cache. So moving PT_INTERP does not
    -- merely stop us from *shipping* those libraries — it removes the host
    -- fallback entirely. "Only dlopen'd on demand, so no worse than today" is
    -- false: today they resolve off the host, afterwards they resolve nowhere.
    --
    -- So the closure has to be complete for soft deps too. libX11, libXext,
    -- libXi and libXrender are already in this index (the graphics work); the
    -- blockers are `libXtst` and `libasound`, which are not. When both exist,
    -- declare glibc plus those six and the switch is a one-line change.
    -- Until then this stays on the host loader deliberately, because a
    -- self-contained JVM that cannot open a window is a regression.
    xpm = {
        linux = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["21"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["17"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["11"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["8"] = { ref = "8.0.512+9" },
            ["8.0.512"] = { ref = "8.0.512+9" },
            ["8u512b09"] = { ref = "8.0.512+9" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "621f7196f0b682fb557da58bec89bd7dfe5419811fe1c0ba75c9cc8432f084c7",
                },
            },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/linux/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "bb8a93f9ae6e7a693b2b721e85dbeff26ae1a77447985a8d7afcdd9c7cf6222e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/aarch64/linux/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "8c72816a6b308842d5ed1f13e5826b69c567da4784f7238d7e800efa71fe54b1",
                },
            },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/linux/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "0b0ac5eab6db6abaec68c9913bcddb31321e5da411c45073d520d9c125e6f7b4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/linux/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "1d808f4b558e9de63d8ba3ead21ffc8b9de204894eff3c19d52c1480aa17cc58",
                },
            },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.33_10.tar.gz",
                    sha256 = "c4b8eaf56c93b95b689ffc08d155df1bcdbbffb666f8f71d21d97aedaea6f0ec",
                },
                aarch64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.33_10.tar.gz",
                    sha256 = "60b0fb79bb678b6fae3e499c7b0a353e68633ed0ab69d1a6bafe6092ed1e59e4",
                },
            },
            ["8.0.512+9"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u512b09.tar.gz",
                    sha256 = "fb3bfa869012419b562bb4235d0d83ec4f8c1dda62ae432ba20c6c3a7e43f7e4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_aarch64_linux_hotspot_8u512b09.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/aarch64/linux/OpenJDK8U-jdk_aarch64_linux_hotspot_8u512b09.tar.gz",
                    },
                    sha256 = "01263df22c4553f63146bbae807e70cd4628dd0d9ec7582f01cb2453f7c69aaa",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["21"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["17"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["11"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["8"] = { ref = "8.0.512+9" },
            ["8.0.512"] = { ref = "8.0.512+9" },
            ["8u512b09"] = { ref = "8.0.512+9" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_mac_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_mac_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "a5ac9c46dad47ac06df35e36d096913195d8da1f3f71918828bcc2cfe33869b7",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "5a101c54abf5a9f16c0f70d8c38ba99e6567c1ba213378f0bb04497284f051bd",
                },
            },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_mac_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/mac/OpenJDK21U-jdk_x64_mac_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "1b5eff1741bb83d32e2e19aade71452bb42e40f047c01d3e178d438304c9a26d",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/aarch64/mac/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "48067f2b7c958ed104a9d8a5749be7d25220b0a356b4d2d1bcfaab3e16ad0b14",
                },
            },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_mac_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/mac/OpenJDK17U-jdk_x64_mac_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "63a1469b52a8063a9f70e539f815093f3a33ef71e6f901b5f43545dbe4e72858",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/mac/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "2a88ccb044a8fb00957be93245da6357c11b55717511509d147cbcc5d93b2109",
                },
            },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_mac_hotspot_11.0.33_10.tar.gz",
                    sha256 = "11e3e9de3ce65ff957aee9b4b76876553e9d328cab9aede47996463625c88887",
                },
                aarch64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_aarch64_mac_hotspot_11.0.33_10.tar.gz",
                    sha256 = "6ef5b027206691439b2dcb2fc05adc13cc7f5b6e75a08fce8f75ee188adc7751",
                },
            },
            ["8.0.512+9"] = {
                -- Temurin 8 publishes no macosx aarch64 (Apple Silicon) binary.
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_mac_hotspot_8u512b09.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/x64/mac/OpenJDK8U-jdk_x64_mac_hotspot_8u512b09.tar.gz",
                    },
                    sha256 = "314e8acc9dd87a63e13c05345fa4a78bda567b452f7e956c80abd4c629851eff",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["21"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["17"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["11"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["8"] = { ref = "8.0.512+9" },
            ["8.0.512"] = { ref = "8.0.512+9" },
            ["8u512b09"] = { ref = "8.0.512+9" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4_7.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4_7.zip",
                    },
                    sha256 = "7caab7db43bf4b94a2e6252c699e70d90084f9aa7c943cd3414761fd540937ae",
                },
            },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13.1_2.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/windows/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13.1_2.zip",
                    },
                    sha256 = "bbebea1469996b276683c9299c227b294f85c847039c82633218186a4ad4fbf2",
                },
            },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_windows_hotspot_17.0.21.1_2.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.21.1_2.zip",
                    },
                    sha256 = "eafba0944f777abdc74d5aad16049c9b5a1275b6ce99e2939ba9f7f3e6f08c87",
                },
            },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_windows_hotspot_11.0.33_10.zip",
                    sha256 = "cff2e75657c96a718974732b4a7b2c81a245a0b2ea44e6d8ea08cd0248d8fa9d",
                },
            },
            ["8.0.512+9"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u512b09.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/x64/windows/OpenJDK8U-jdk_x64_windows_hotspot_8u512b09.zip",
                    },
                    sha256 = "20f248ddd600f900cd9b235d50d54cdb27e7b750f140d381176a7612c53663cd",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Temurin 11+ archives expand to `jdk-<version>/`, while Temurin 8 uses
-- `jdk8u<update>-b<build>/` (e.g. `jdk8u512-b09/`). What sits under it is
-- NOT uniform across OSes: linux and windows put the runtime right there
-- (`<root>/bin/java`), while macOS ships a signed .jdk bundle and buries it
-- one level down:
--
--   linux/windows  jdk-25.0.4+7/bin/java   | jdk8u512-b09/bin/java
--   macosx         jdk-25.0.4+7/Contents/Home/bin/java
--                  jdk-25.0.4+7/Contents/_CodeSignature/...
--
-- Moving the bundle root into install_dir on macOS would leave every shim
-- (and JAVA_HOME) pointing at a directory with no `bin/`, so the macOS
-- payload is the inner `Contents/Home`. After this, install_dir() IS
-- JAVA_HOME on all three platforms and the rest of the recipe is
-- arch/os-agnostic.
local function payload_root()
    local version = pkginfo.version()
    local update, build = version:match("^8%.0%.(%d+)%+(%d+)$")
    if update and build then
        return string.format("jdk8u%s-b%02d", update, tonumber(build))
    end
    return "jdk-" .. version
end

local function payload_dir()
    local root = payload_root()
    if os.host() == "macosx" then
        return path.join(root, "Contents", "Home")
    end
    return root
end

function install()
    -- Idempotent across xim engines (same rationale as perl.lua): some stage
    -- the extracted payload into install_dir() before/without the hook, others
    -- leave it in the hook CWD for us to move. Never wipe install_dir before a
    -- replacement payload is confirmed, and never report success unless the
    -- launcher is actually in place — `return true` over an empty dir gets
    -- stamped as installed and leaves dangling xvm shims behind.
    local exe = os.host() == "windows" and "java.exe" or "java"
    local staged = path.join(pkginfo.install_dir(), "bin", exe)
    if os.isfile(staged) then return true end

    local payload = payload_dir()
    if os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end

    if not os.isfile(staged) then
        log.error("jdk-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
        return false
    end
    return true
end

-- Shared launcher names, and the flavor-tagged version they register under.
--
-- `java`/`javac`/... are NOT owned by Temurin: jdk-zulu, jdk-oracle,
-- jdk-microsoft and friends are all builds of the SAME upstream OpenJDK tag,
-- so a sibling recipe would want to register `java` at the very same
-- "25.0.4+7". xvm refuses that outright -- the second package's whole config
-- batch is rejected:
--
--   field: /nodes/0
--   hint:  another package already owns this exact name and version;
--          uninstall that package first, or install this one at a different
--          version
--   Error: [jdk-<other>] failed: config hook failed
--
-- i.e. with the plain numeric version, installing Temurin would make every
-- other JDK distribution uninstallable, which defeats the whole point of
-- putting the flavor in the package name. So the shared names register as
-- `<version>-temurin`, exactly the idiom musl-gcc.lua uses to share `gcc`
-- with gcc.lua ("16.1.0-musl"). `xlings use java 25.0.4+7-temurin` then names
-- one flavor unambiguously, and the whole set still switches together via the
-- binding root below.
local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "temurin"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

local function program_exe(prog)
    return os.host() == "windows" and (prog .. ".exe") or prog
end

-- JDK 8 predates `jshell` (introduced in JDK 9), so only register/remove
-- launchers that actually exist in `bindir` (falling back to `PROGRAMS` if
-- `bindir` is already gone during uninstall).
local function installed_programs(bindir)
    if not os.isdir(bindir) then
        return PROGRAMS
    end
    local present = {}
    for _, prog in ipairs(PROGRAMS) do
        if os.isfile(path.join(bindir, program_exe(prog))) then
            table.insert(present, prog)
        end
    end
    return present
end

function config()
    -- install_dir() is the JDK home on every platform (see payload_dir).
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    -- Root of this release's binding group. The package name already carries
    -- the flavor, so the root keeps the plain version and `xlings use
    -- jdk-temurin 25.0.4+7` switches every program bound to it in one step.
    -- `type = "group"` because the node names no artifact: there is no
    -- `bin/jdk-temurin` to exec, and left as the default `program` kind it
    -- becomes a shim that can only ever fail, which `self doctor` then reports
    -- as an orphan (openxlings/xlings#452). Same idiom as gcc.lua / rust.lua.
    local binding = "jdk-temurin@" .. pkginfo.version()
    xvm.add("jdk-temurin", { type = "group" })

    -- Nearly every JVM-ecosystem tool (maven, gradle, the wrappers, IDE
    -- launchers) locates a JDK through JAVA_HOME rather than PATH, so a JDK
    -- that only registers shims is half-installed. xvm attaches these to the
    -- shim, so they apply to processes started through `java`/`javac`/... and
    -- follow `xlings use` automatically instead of pinning one JDK in a
    -- profile file. Note the boundary: this does NOT export JAVA_HOME into
    -- the user's interactive shell, so a tool invoked outside these shims
    -- still needs its own JAVA_HOME (printed below once at install time).
    local env = { JAVA_HOME = java_home }

    -- Core developer-facing launchers. The tree also carries ~90 more tools
    -- (jlink, jmod, jpackage, keytool, ...); they stay reachable through
    -- <install>/bin and are deliberately NOT registered, so installing the
    -- JDK doesn't shadow unrelated system tools.
    local registered = installed_programs(bindir)
    for _, prog in ipairs(registered) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk-temurin: %s registered as %s; other JDK tools live in %s",
             table.concat(registered, "/"), flavor_version(), bindir)

    return true
end

function uninstall()
    -- Both removals are version-scoped: another installed JDK version (or, for
    -- the shared names, another JDK distribution) must keep its nodes.
    local bindir = path.join(pkginfo.install_dir(), "bin")
    for _, prog in ipairs(installed_programs(bindir)) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk-temurin", pkginfo.version())
    return true
end
