package = {
    spec = "2",

    homepage = "https://github.com/HuxerUI/HuxerUI",
    name = "huxerui",
    description = "HuxerUI SDK — a modern C++20 cross-platform declarative UI framework "
        .. "(shared state, layout, rendering, native platform backends), with the "
        .. "`huxerui` CLI plus the `hrc` resource compiler and `hcg` code generator.",

    maintainers = {"HuxerUI contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/HuxerUI/HuxerUI",
    docs = "https://github.com/HuxerUI/HuxerUI#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "ui", "framework", "library"},
    keywords = {"huxerui", "ui", "declarative", "cpp20", "gtk4", "framework", "sdk"},

    -- The programs every consumer reaches for. `hrc`/`hcg` live under the
    -- platform-tools tree (share/huxerui/tools/<os>/<arch>/), not in bin/, so
    -- each gets an explicit bindir in config().
    programs = {"huxerui", "hrc", "hcg"},
    xvm_enable = true,

    xpm = {
        -- THE TOOLCHAIN AND THE GTK STACK COME FROM XLINGS.
        --
        -- This REPLACES an earlier decision to leave the whole stack on the
        -- host loader, and the reversal is deliberate, so the old argument is
        -- recorded here rather than deleted.
        --
        -- What it said: a UI SDK should bind the desktop the user is actually
        -- logged into, because vendoring GTK4 under an application makes a
        -- second, worse desktop -- its own theme, its own settings daemon, its
        -- own input methods. That is a real cost and it is still real.
        --
        -- Three things outweigh it.
        --
        -- 1. THE PROMISE WAS ALREADY BROKEN. Upstream's README says installing
        --    through xlings "brings the tools the SDK builds with -- CMake,
        --    mcpp and the rest of the toolchain -- so a fresh machine needs
        --    nothing else." This descriptor declared NO deps at all, so a
        --    fresh machine got the SDK and then failed at the first build:
        --        Checking for module 'gtk4>=4.14'
        --          Package 'gtk4', required by 'virtual:world', not found
        --    `huxerui doctor` reported the HOST's cmake. Measured on a box
        --    with no GTK4 development packages.
        --
        -- 2. THE HOST BINDING WAS ALREADY NOT HAPPENING. On any machine that
        --    has `xim:gtk4` installed for any other reason, this SDK's own
        --    DT_NEEDED closure already resolves inside data/xpkgs --
        --    verify-huxerui-closure.sh walks 63 objects and 230 edges and
        --    reports exactly that. The old comment's outcome was therefore
        --    incidental, not enforced. Declaring the deps makes it a
        --    guarantee instead of an accident.
        --
        -- 3. THE OTHER BUILD PATH ALREADY CHOSE THIS. Upstream's own mcpp
        --    manifest pins the same 36-entry closure and says "THE GTK STACK
        --    COMES FROM XLINGS, NOT FROM THE MACHINE". Having the xlings
        --    install disagree with the mcpp build about where GTK comes from
        --    is the confusing state, not a safeguard.
        --
        -- A project that specifically wants host-desktop binding still gets
        -- it: build with the distribution's GTK4 development packages and
        -- CMake outside this payload, which is what cmake/platform/Linux.cmake
        -- has always supported.
        --
        -- The DT_NEEDED closure of bin/huxerui + lib/libhuxerui.so, enumerated
        -- from the 0.3.0 linux-x86_64 artifact with readelf (unchanged from
        -- 0.2.0; re-measured at the bump by verify-huxerui-closure.sh, which
        -- walked 63 objects and resolved all 230 edges inside data/xpkgs):
        --   glibc/gcc-runtime half:  libc.so.6, libm.so.6, libdl.so,
        --                            libstdc++.so.6, libgcc_s.so.1
        --   GTK4 desktop stack:      libgtk-4.so.1, libgdk_pixbuf-2.0.so.0,
        --                            libsoup-3.0.so.0, libgio-2.0.so.0,
        --                            libgobject-2.0.so.0, libglib-2.0.so.0,
        --                            libpango-1.0.so.0, libpangocairo-1.0.so.0,
        --                            libcairo.so.2
        --   (plus libc++_shared.so from the bundled Android runtime payload)
        --
        -- Every soname above now has a package, so the closure is complete.
        linux = {
            -- The build systems the SDK is driven with. The README promises
            -- both come along; without them a fresh machine falls back to the
            -- host's cmake, or has none.
            deps = {
                "xim:cmake",
                "xim:mcpp",

                -- The transitive .pc closure of gtk4 + epoxy + libsoup, the
                -- same set and the same floors upstream's mcpp.toml pins. A
                -- missing entry surfaces as `Package <x> was not found in the
                -- pkg-config search path`, which names it.
                "xim:cairo@>=1.18.4",
                "xim:expat@>=2.6.2",
                "xim:fontconfig@>=2.15.0.1",
                "xim:freetype@>=2.13.2",
                "xim:fribidi@>=1.0.13",
                "xim:gdk-pixbuf@>=2.44.8",
                "xim:glib@>=2.88.3",
                "xim:graphene@>=1.10.8",
                "xim:gtk4@>=4.16.13",
                "xim:harfbuzz@>=14.4.0",
                "xim:libX11@>=1.8.10",
                "xim:libXau@>=1.0.11",
                "xim:libXdmcp@>=1.1.5",
                "xim:libXext@>=1.3.6",
                "xim:libXft@>=2.3.9",
                "xim:libXrender@>=0.9.11",
                "xim:libdatrie@>=0.2.14",
                "xim:libepoxy@>=1.5.10",
                "xim:libffi@>=3.4.4",
                "xim:libglvnd@>=1.7.0.1",
                "xim:libjpeg-turbo@>=3.2.0",
                "xim:libpng@>=1.6.43",
                "xim:libpsl@>=0.23.3",
                "xim:libselinux@>=3.11",
                "xim:libsoup@>=3.6.6",
                "xim:libthai@>=0.1.30",
                "xim:libtiff@>=4.7.2",
                "xim:libxcb@>=1.17.0",
                "xim:nghttp2@>=1.70.0",
                "xim:pango@>=1.52.1",
                "xim:pcre2@>=10.42",
                "xim:pixman@>=0.42.2",
                "xim:sqlite@>=3.53.4",
                "xim:util-linux@>=2.40.2",
                "xim:xorgproto@>=2024.1",
                "xim:zlib@>=1.3.1",
            },
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-linux-${arch}.${ext}",
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                sha256 = {
                    x86_64  = "5413ccd9d35d0ad50c08c67045d73cb9faff23c04005a554af0faa7a914eb916",
                    aarch64 = "39a6529d14698cd0e168e62a6a7aae482e6914ce409feaa5d5ab524955bd1d41",
                },
            },
            ["0.2.0"] = {
                sha256 = {
                    x86_64  = "f9da279919abc9f6b6a15d0115ce4a859ad9499396c5ee7ba2cb6667187a194a",
                    aarch64 = "17a48d107f8fe9a6467e2c1acd7c7254980bce0fc6420b44998d444261bd18ee",
                },
            },
        },
        macosx = {
            -- The build systems the SDK is driven with. No GTK: the macOS
            -- platform layer binds AppKit/Metal and friends as frameworks,
            -- which the system SDK provides.
            deps = {
                "xim:cmake",
                "xim:mcpp",
            },
            -- xlings spells macOS `macosx`; upstream asset names spell it
            -- `macos`. Platform-scope source override absorbs the difference.
            --
            -- Upstream's mac assets name the ARM build `macos-arm64` (the alias)
            -- while the Linux ones use the canonical `linux-aarch64`, so the
            -- `${arch}` template alone would 404 on Apple Silicon. `arch_alias`
            -- maps the canonical key to upstream's spelling for this platform.
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-macos-${arch_alias}.${ext}",
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "8b29dffe33cdb5b496f17e6c7905725e63f0a17f5e239b6c7c4f9719ea752f95",
                    aarch64 = "87840f81bfc88b595ea1f23b825d9078be9bd609a526ee3e9dac6ff3010a099e",
                },
            },
            ["0.2.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "08bcc11c1b3959d2ee9b4a763b81dfef84c6a78414afd5f06409bc0a8ec80b3e",
                    aarch64 = "3c30480e525c10fa8ed3e820e1cbb02b4970860a99167f1d7a63b58697101104",
                },
            },
        },
        windows = {
            -- The build systems the SDK is driven with. No GTK: the Windows
            -- backend is Win32 + Direct2D/DirectWrite, linked against the
            -- Windows SDK.
            deps = {
                "xim:cmake",
                "xim:mcpp",
            },
            -- windows asset is a .zip; ${ext} resolves to `zip` on windows.
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-windows-${arch}.${ext}",
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                sha256 = {
                    x86_64 = "d1aca11de979070f950f16d319492d3f9fc0355d1ddbcb9bb926d79872bc2ef4",
                },
            },
            ["0.2.0"] = {
                sha256 = {
                    x86_64 = "0793cd8d74ed2959ccec20af6fb5800959b9090113712e97781dbc78db9c9143",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.subos")
import("xim.libxpkg.system")

-- The upstream archives wrap the payload in a single
-- `huxerui-sdk-<version>-<os>-<arch>/` directory. Locate it by content rather
-- than by reconstructing the name, so a flat re-pack or a stray sibling does
-- not silently install the wrong tree.
local function payload_root()
    local file = pkginfo.install_file() or ""
    local base = path.directory(file)

    -- Wrapped shape: <base>/huxerui-sdk-<ver>-<os>-<arch>/
    local stem = (file:match("[^/\\]+$") or "")
        :gsub("%.tar%.gz$", "")
        :gsub("%.zip$", "")
    if stem ~= "" and os.isdir(path.join(base, stem)) then
        return path.join(base, stem)
    end

    -- Fallback: scan siblings for the one directory that is an SDK root.
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "include", "huxerui", "huxerui.h"))
           and os.isfile(path.join(d, "lib", "cmake", "HuxerUI", "HuxerUIConfig.cmake")) then
            return d
        end
    end

    error("cannot locate the HuxerUI SDK payload under '" .. tostring(base) .. "'")
end

-- True when this payload is the Windows build (zip, .exe, no ELF).
local function is_windows_payload(dir)
    return os.isfile(path.join(dir, "bin", "huxerui.exe"))
end

-- The platform-tools directory that holds hrc / hcg for THIS payload.
-- share/huxerui/tools/<os>/<arch>/{hrc,hcg}
local function tools_bindir(dir)
    for _, osname in ipairs({"windows", "linux", "macos"}) do
        local osd = path.join(dir, "share", "huxerui", "tools", osname)
        if os.isdir(osd) then
            for _, ad in ipairs(os.dirs(path.join(osd, "*"))) do
                if os.isfile(path.join(ad, "hrc"))
                   or os.isfile(path.join(ad, "hrc.exe")) then
                    return ad
                end
            end
        end
    end
    return nil
end

function install()
    local src = payload_root()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(src, dir)

    -- Assert the four artifacts upstream's own `is_sdk` check requires, so a
    -- truncated download fails here with a named file instead of later as a
    -- cmake "cannot locate HUXERUI_HOME".
    local exe = is_windows_payload(dir) and "huxerui.exe" or "huxerui"
    local required = {
        path.join("bin", exe),
        path.join("include", "huxerui", "huxerui.h"),
        path.join("lib", "cmake", "HuxerUI", "HuxerUIConfig.cmake"),
        path.join("share", "huxerui", "resources", "huxerui", "resources.bin"),
    }
    local missing = {}
    for _, rel in ipairs(required) do
        if not os.isfile(path.join(dir, rel)) then
            table.insert(missing, rel)
        end
    end
    if #missing > 0 then
        error("huxerui payload is incomplete; missing:\n    "
              .. table.concat(missing, "\n    "))
    end
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    -- PKG_CONFIG_PATH RIDES THE SHIM, not the subos.
    --
    -- The deps above install the GTK stack, and each of those packages calls
    -- `sysroot.declare_pkgconfig`, which aggregates every payload's .pc into
    -- ONE directory: <subos>/usr/lib/pkgconfig. Nothing points pkg-config at
    -- it, though -- a subos does not remap `/`, so the plain
    -- /usr/bin/pkg-config inside one searches the HOST's default pc_path and
    -- finds none of it. Verified: `xlings subos use default --cmd
    -- 'pkg-config --modversion gtk4'` fails, with and without --sandbox.
    --
    -- `subos.env` would fix it only inside `xlings subos use` (mesa.lua says
    -- so), and the documented workflow is `huxerui build linux` from an
    -- ordinary shell. A per-shim env DOES reach that: cmake is a CHILD of this
    -- shim and inherits it. This is the msvc.lua shape, which feeds INCLUDE
    -- and LIB to cl the same way -- and the reason HUXERUI_HOME below is NOT
    -- done this way still holds, because a consumer may run cmake directly,
    -- without the shim.
    --
    -- xvm PREPENDS rather than overwrites -- measured, with a caller value:
    --     PKG_CONFIG_PATH=/tmp/caller-marker huxerui build linux
    --     -- PCP_SEEN=[<subos>/usr/lib/pkgconfig:/tmp/caller-marker]
    -- so a consumer pointing at their own .pc keeps it, and a host GTK4 dev
    -- install still wins nothing it did not already win.
    --
    -- Set on every platform: it is one path, harmless where nothing reads it.
    local sysroot_pc = path.join(system.subos_sysrootdir(), "usr", "lib", "pkgconfig")

    -- `package.name` IS one of the programs ("huxerui"), so there is no
    -- separate binding root to register -- the program node is the root, the
    -- same shape slang.lua uses. Registering both `xvm.add("huxerui")` and a
    -- bare root of the same name trips xvm-duplicate-registration.
    xvm.add("huxerui", { bindir = path.join(idir, "bin"),
                         envs = { PKG_CONFIG_PATH = sysroot_pc } })

    local tdir = tools_bindir(idir)
    if tdir then
        xvm.add("hrc", { bindir = tdir })
        xvm.add("hcg", { bindir = tdir })
    else
        log.warn("no platform-tools dir (hrc/hcg) found under share/huxerui/tools; "
                 .. "registering only the huxerui CLI")
    end

    -- HUXERUI_HOME is read by the consumer's BUILD system (cmake's
    -- `add_subdirectory("${HUXERUI_HOME}" ...)`, gradle, xcode), not by the
    -- `huxerui` shim alone, so a per-shim env cannot reach it. It belongs in
    -- the subos, exactly like msvc's VSINSTALLDIR. Probe with type(): import()
    -- answers an unknown module member with a truthy stub.
    if type(subos.env) == "function" then
        subos.env{ var = "HUXERUI_HOME", op = "set", value = "${pkgdir}", binding = binding }
    end
    return true
end

function uninstall()
    xvm.remove("hrc")
    xvm.remove("hcg")
    xvm.remove("huxerui")
    -- HUXERUI_HOME is provider-scoped via subos.env; no manual cleanup here.
    return true
end
