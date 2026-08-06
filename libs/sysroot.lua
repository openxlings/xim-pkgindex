-- Shared sysroot installation helpers for xim-pkgindex.
--
-- Loaded by package config() hooks via:
--     import("xim.pkgindex.sysroot")
--
-- Requires xlings >= 0.4.29 (libxpkg fs module + `xim.pkgindex.*`
-- custom-module loader, both shipped in xlings v0.4.29 / libxpkg v0.0.40).
-- Older xlings versions have no `xim.pkgindex.*` resolver, so the import
-- falls through to the unknown-module stub and any callsite hits a nil
-- error — that's the right signal to bump xlings.

import("xim.libxpkg.fs")
import("xim.libxpkg.xvm")

local sysroot = {}

-- Immediate children of DIR, enumerated with a single shell `ls`.
--
-- One fork and one readdir. See install_headers below for why this is not
-- fs.entries: under proot, ~400 std::filesystem stat() calls on a 130-entry
-- directory is enough to poison the talloc pool.
function sysroot.entries(dir)
    local names = {}
    local f = io.popen(string.format([[ls -1 "%s" 2>/dev/null]], dir))
    if not f then return names end
    for line in f:lines() do
        local name = line:gsub("[\r\n]+$", "")
        if name ~= "" then table.insert(names, name) end
    end
    f:close()
    return names
end

-- Refuse, readably, on a client that lacks a capability this package needs.
--
-- The counterpart to declare_headers: use that while a legacy fallback is
-- still worth carrying, use this once it has been dropped.
--
-- Why this and not a `min_xlings` field in the recipe: a field can only be
-- read by clients that implement it, and the clients that need to be told
-- are precisely the ones that do not. A version floor expressed as data can
-- never reach them. `raise` from config() can, because every client back to
-- 0.4.29 already runs the hook and prints the message:
--
--     [warn] config hook failed for <pkg>: <file>:<line>: <message>
--     [error] [<pkg>] failed: config hook failed
--
-- Verified against a released 0.4.69, not assumed.
--
-- Caveat worth knowing: config() runs after download and extraction, so the
-- refusal costs the user a download. That is the price of a message they can
-- act on; a field they cannot read would cost them a confusing failure
-- instead ("unsupported registration node kind").
function sysroot.require_capability(present, what, since)
    if present then return end
    raise(string.format(
        "this package needs xlings >= %s (this client has no %s); "
        .. "run: xlings self update", since, what))
end

-- Declare the immediate children of INSTALL_DIR/SRC_REL as file assets, so
-- xlings owns them: they follow `xlings use` and are removed with the
-- release instead of by a hand-written mirror of this call in uninstall().
--
-- Returns false when the running client has no `xvm.files`, so the caller
-- falls back to install_headers and behaves exactly as it did before. That
-- probe -- capability, never version -- is the contract in
-- docs/V2/xpackage-spec.md; `xvm.files` arrived with the node kind it
-- declares, in a libxpkg that is linked into the xlings binary.
--
-- SRC_REL is relative to the payload root and DST_REL to the subos root,
-- and both must stay relative: a payload is shared between subos, so an
-- absolute destination recorded against it would be right for the subos
-- that installed it and wrong for every other one.
--
-- ONE SEMANTIC DIFFERENCE from install_headers, and it is deliberate:
-- install_headers skips an entry that already exists, so the first package
-- to claim a name keeps it. A declared asset is placed unconditionally, so
-- the last one wins -- but it is now *recorded*, which is the point: two
-- packages claiming one path becomes visible state rather than a silent
-- race decided by install order. Only migrate a directory whose names are
-- yours (`openssl/`, `python3.13/`); for a package that scatters entries
-- into a shared namespace, check what else claims them first.
function sysroot.declare_headers(install_dir, src_rel, dst_rel, binding)
    if not xvm.files then return false end
    local src_dir = path.join(install_dir, src_rel)
    if not os.isdir(src_dir) then return true end
    for _, name in ipairs(sysroot.entries(src_dir)) do
        xvm.files{
            src = path.join(src_rel, name),
            dst = path.join(dst_rel, name),
            binding = binding,
        }
    end
    return true
end

-- declare_headers, but for a directory whose names are NOT yours.
--
-- declare_headers stops at the immediate children, which is right when the
-- package owns those names (`openssl/`, `python3.13/`, glibc's 130). The X11
-- stack is the case it cannot express: eight packages -- xorgproto, libX11,
-- libXau, libXdmcp, libXext, libXfixes, libXxf86vm, libxshmfence -- each ship
-- part of one `X11/` directory. Declaring that child places the whole
-- directory as a single asset, and a file asset is placed by rename(2), so
-- the eighth package to install REPLACES the other seven. install_headers
-- fails the same case from the other side: it skips a name that already
-- exists, so the first package wins and the other seven are dropped.
--
-- Neither is a merge, and `usr/include` shared by eight packages needs one.
--
-- So: recurse, and declare at the leaves. Directories are never declared,
-- which is the whole point -- xlings creates the parent of each asset, so
-- `usr/include/X11/` becomes a real directory holding symlinks contributed by
-- all eight, exactly as a distribution's /usr/include is assembled. Only two
-- packages shipping the same *file* now collide, and that collision is
-- recorded per file rather than swallowing a directory.
--
-- Cost is one node per header: 270 for the whole graphics stack. Use
-- declare_headers when the names are yours -- it is one node per directory --
-- and this when they are not.
function sysroot.declare_headers_tree(install_dir, src_rel, dst_rel, binding)
    if not xvm.files then return false end
    if not os.isdir(path.join(install_dir, src_rel)) then return true end
    sysroot.__declare_tree(install_dir, src_rel, dst_rel, binding, 0)
    return true
end

function sysroot.__declare_tree(install_dir, src_rel, dst_rel, binding, depth)
    -- Header trees are three or four deep (`X11/extensions/`, `libdrm/`).
    -- The cap is a stop for a payload that symlinks a directory back to an
    -- ancestor, which would otherwise walk until Lua runs out of stack.
    if depth > 8 then return end
    for _, name in ipairs(sysroot.entries(path.join(install_dir, src_rel))) do
        local child = path.join(src_rel, name)
        if os.isdir(path.join(install_dir, child)) then
            sysroot.__declare_tree(install_dir, child,
                                   path.join(dst_rel, name), binding, depth + 1)
        else
            xvm.files{
                src = child,
                dst = path.join(dst_rel, name),
                binding = binding,
            }
        end
    end
end

-- Install headers from SRC_DIR into DST_DIR — strictly non-recursive.
--
-- Only the immediate children of SRC_DIR are processed. Each entry
-- that doesn't already exist in DST_DIR gets a single symlink; entries
-- that already exist (from the host bind-mount or from another package)
-- are skipped entirely.
--
-- This "skip-if-exists" policy is correct for sysroot headers because:
--   * If the host already has `/usr/include/sys/` (233 real dirs on a
--     typical Ubuntu bind-mount), those headers are already usable by
--     the subos GCC — we don't need to replace or merge them.
--   * If a prior xlings package already symlinked `scsi/` → pkg-A's
--     dir, and now pkg-B also has `scsi/`, pkg-B's entries are a
--     superset concern of the caller (who should ship a merged dir
--     or use a different name), not this helper's.
--   * Crucially, this keeps the proot syscall count at ≤ N where N is
--     the number of top-level entries in SRC_DIR (~130 for glibc),
--     regardless of how large the destination tree is. The previous
--     "recurse into existing real dirs" path blew up to 500+ ops when
--     glibc's 20 subdirs overlapped with Ubuntu's host `/usr/include`
--     (e.g. sys/ alone has 87 host entries), poisoning proot's talloc
--     pool and crashing npm install in the same session.
function sysroot.install_headers(src_dir, dst_dir)
    if not os.isdir(src_dir) then return end
    fs.mkdir_p(dst_dir)
    -- Enumerate source entries via a single shell `ls` (one fork, one
    -- readdir — proot-safe). Then for each name, use `os.isdir` /
    -- `os.isfile` (the old runtime APIs that proot translates correctly)
    -- to test existence. Only entries that don't already exist in dst
    -- get a single `fs.symlink` call.
    --
    -- Why not fs.entries: even read-only fs.entries + fs.is_symlink +
    -- fs.is_file + fs.is_directory on 130 entries under proot is ~400+
    -- C++ std::filesystem stat() calls that proot traces via ptrace —
    -- enough to poison the talloc pool on some kernel/proot combos.
    -- The shell `ls` + Lua `os.isdir`/`os.isfile` path uses ~2N
    -- syscalls total (one readdir + one stat per entry) and goes
    -- through proot's simpler absolute-path translation, not the
    -- dir-fd-relative openat path.
    for _, name in ipairs(sysroot.entries(src_dir)) do
        local dst = path.join(dst_dir, name)
        -- Skip if anything already exists at dst (host bind-mount,
        -- prior package, or prior install). os.isdir/os.isfile cover
        -- real entries + symlinks that resolve to dirs/files.
        if os.isdir(dst) or os.isfile(dst) then
            -- already present, skip
        else
            local src = path.join(src_dir, name)
            fs.symlink(src, dst)
        end
    end
end

-- The legacy fallback for declare_headers_tree: same recursive merge, done
-- by hand for a client with no `xvm.files`.
--
-- Where install_headers skips a name that already exists, this descends into
-- it. A directory present on both sides is made a real directory in the
-- sysroot and both contents land in it; only at a *file* that already exists
-- does the first claimant still win. Without that descent an existing `X11/`
-- -- from the host bind-mount or from whichever package installed first --
-- hides every other package's X11 headers.
function sysroot.install_headers_tree(src_dir, dst_dir, depth)
    if not os.isdir(src_dir) then return end
    if (depth or 0) > 8 then return end
    fs.mkdir_p(dst_dir)
    for _, name in ipairs(sysroot.entries(src_dir)) do
        local src = path.join(src_dir, name)
        local dst = path.join(dst_dir, name)
        if os.isdir(src) then
            sysroot.install_headers_tree(src, dst, (depth or 0) + 1)
        elseif not (os.isdir(dst) or os.isfile(dst)) then
            fs.symlink(src, dst)
        end
    end
end

-- Register a payload's shared libraries so they appear in `<subos>/lib`.
--
-- Headers alone do not make a sysroot. A package installed through xlings
-- RUNS without this -- elfpatch writes the consumer's RPATH from
-- exports.runtime.libdirs, straight into the payload -- but nothing can be
-- LINKED against it: `gcc -lEGL` searches the subos's lib directory, and the
-- payload is not on that path. The stack was in the odd position of shipping
-- headers a compiler could find and libraries it could not.
--
-- Same mechanism zlib and glibc use, enumerated instead of hand-listed: at
-- eighteen packages a per-package list is a place for a name to go missing,
-- and the failure (one undefined symbol at link time) does not name the list.
--
-- Immediate children only, which is what keeps mesa's `lib/dri/*.so` out --
-- those are driver modules loaded by path through LIBGL_DRIVERS_PATH, not
-- link targets, and registering them would put twelve drivers in `<subos>/lib`
-- for anything to link against by accident.
function sysroot.declare_libs(install_dir, src_rel, binding, version)
    local libdir = path.join(install_dir, src_rel)
    if not os.isdir(libdir) then return end
    for _, name in ipairs(sysroot.entries(libdir)) do
        if (name:find("%.so$") or name:find("%.so%."))
           and os.isfile(path.join(libdir, name)) then
            xvm.add(name, {
                version = version,
                type = "lib",
                bindir = libdir,
                filename = name,
                alias = name,
                binding = binding,
            })
        end
    end
end

return sysroot
