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

return sysroot
