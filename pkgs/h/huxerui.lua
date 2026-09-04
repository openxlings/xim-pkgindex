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
        -- INTENTIONALLY ON THE HOST LOADER (same decision as code.lua). This is
        -- a decision, not an unfinished migration, recorded so a later sweep for
        -- host-loader payloads does not "fix" it by adding a glibc dep.
        --
        -- The DT_NEEDED closure of bin/huxerui + lib/libhuxerui.so, enumerated
        -- from the 0.2.0 linux-x86_64 artifact with readelf:
        --   glibc/gcc-runtime half:  libc.so.6, libm.so.6, libdl.so,
        --                            libstdc++.so.6, libgcc_s.so.1
        --   GTK4 desktop stack:      libgtk-4.so.1, libgdk_pixbuf-2.0.so.0,
        --                            libsoup-3.0.so.0, libgio-2.0.so.0,
        --                            libgobject-2.0.so.0, libglib-2.0.so.0,
        --                            libpango-1.0.so.0, libpangocairo-1.0.so.0,
        --                            libcairo.so.2
        --   (plus libc++_shared.so from the bundled Android runtime payload)
        --
        -- GTK4, GDK-Pixbuf and libsoup-3 have no package in this index (no
        -- gtk.lua / gdk-pixbuf.lua / libsoup.lua). Declaring only the in-index
        -- half (glibc, pango, cairo, …) would move PT_INTERP into our sandbox
        -- and REMOVE the host fallback for the GTK4 half, which then resolves
        -- nowhere (our glibc's ld.so cache path exists on no machine). A UI SDK
        -- is also meant to bind the desktop the user is actually logged into —
        -- vendoring GTK4 would make a second, worse desktop. So the whole
        -- payload stays on the host loader and the host is the provider; the
        -- D2 dep-closure check reports these sonames as notes, not a failure.
        linux = {
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-linux-${arch}.${ext}",
            ["latest"] = { ref = "0.2.0" },
            ["0.2.0"] = {
                sha256 = {
                    x86_64  = "f9da279919abc9f6b6a15d0115ce4a859ad9499396c5ee7ba2cb6667187a194a",
                    aarch64 = "17a48d107f8fe9a6467e2c1acd7c7254980bce0fc6420b44998d444261bd18ee",
                },
            },
        },
        macosx = {
            -- xlings spells macOS `macosx`; upstream asset names spell it
            -- `macos`. Platform-scope source override absorbs the difference.
            --
            -- Upstream's mac assets name the ARM build `macos-arm64` (the alias)
            -- while the Linux ones use the canonical `linux-aarch64`, so the
            -- `${arch}` template alone would 404 on Apple Silicon. `arch_alias`
            -- maps the canonical key to upstream's spelling for this platform.
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-macos-${arch_alias}.${ext}",
            ["latest"] = { ref = "0.2.0" },
            ["0.2.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "08bcc11c1b3959d2ee9b4a763b81dfef84c6a78414afd5f06409bc0a8ec80b3e",
                    aarch64 = "3c30480e525c10fa8ed3e820e1cbb02b4970860a99167f1d7a63b58697101104",
                },
            },
        },
        windows = {
            -- windows asset is a .zip; ${ext} resolves to `zip` on windows.
            source = "https://github.com/HuxerUI/HuxerUI/releases/download/v${version}/huxerui-sdk-${version}-windows-${arch}.${ext}",
            ["latest"] = { ref = "0.2.0" },
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

    -- `package.name` IS one of the programs ("huxerui"), so there is no
    -- separate binding root to register -- the program node is the root, the
    -- same shape slang.lua uses. Registering both `xvm.add("huxerui")` and a
    -- bare root of the same name trips xvm-duplicate-registration.
    xvm.add("huxerui", { bindir = path.join(idir, "bin") })

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
