-- Resolve a library that belongs to the HOST, the way the loader would.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.hostlib")
--
-- WHY THIS EXISTS AS ONE MODULE
--
-- Four places in this ecosystem ask "where is the host's <soname>", and before
-- this module they gave four different answers -- three of them wrong:
--
--   * nvidia-gl-host-link   ldconfig -p + ABI filter + first-wins        correct
--   * compat.glx-runtime    hardcoded list, `ln -sf` LAST-wins, no ABI   wrong
--   * godot                 hardcoded list, no ABI check                 lucky
--   * verify-host-link.sh   one hardcoded Debian path, silent skip       wrong
--
-- The wrong ones are not sloppiness. They are all the same reasonable-looking
-- mistake: assume a directory layout. And there is no layout to assume --
--
--   * The FHS biarch clause says /usr/lib is 32-bit and /usr/lib64 is 64-bit.
--     Red Hat and SUSE follow it.
--   * Debian and Ubuntu explicitly DECLINED that clause and use multiarch:
--     /usr/lib/<triplet>. So on Debian /usr/lib holds 64-bit libraries.
--   * Arch and Gentoo are a third answer again: /usr/lib64 is a symlink to
--     /usr/lib, and 64-bit lives in /usr/lib.
--
-- None of the three is wrong, so a candidate list is not a conservative
-- choice -- it is a choice to be wrong on some distribution. mcpp#352 is that
-- bug: on Fedora the 32-bit /usr/lib/libGLX.so.0 overwrote the correct
-- /usr/lib64 one, and dlopen reported `wrong ELF class: ELFCLASS32`.
--
-- THE THREE RULES
--
--   1. Ask `ldconfig -p` first. That is the loader's own index, built from
--      /etc/ld.so.conf.d/*.conf, and it is the only authority on this host --
--      including paths no list would contain (/usr/lib/wsl/lib on WSL2,
--      /opt/... on hand-rolled installs).
--   2. Filter by ELF class / ABI. `ldconfig -p` tags every entry
--      (`libc6,x86-64`); for the fallback paths we read e_ident[EI_CLASS] out
--      of the file itself. This is what turns "wrong directory" from a
--      silently wrong answer into no answer.
--   3. First hit wins. The one place that got this right returned on first
--      hit; the one that got it wrong overwrote with `ln -sf` in loop order.
--
-- Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §9.2

import("xim.libxpkg.log")

local hostlib = {}

-- ELF class of FILE, read from the file itself: 32, 64, or nil (not an ELF).
--
-- Five bytes, no external tool. `readelf`/`file`/`patchelf` would all work and
-- all three are things that may not be installed at the moment a hook runs --
-- and a probe that answers "cannot tell" by falling through to "looks fine" is
-- the failure this module exists to remove.
function hostlib.elf_class(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local head = f:read(5)
    f:close()
    if not head or #head < 5 then return nil end
    if head:sub(1, 4) ~= "\127ELF" then return nil end
    local class = head:byte(5)
    if class == 1 then return 32 end
    if class == 2 then return 64 end
    return nil
end

-- The ABI token `ldconfig -p` prints for this architecture.
--
-- Keyed by what the recipe is being built for, not by what the host is: these
-- packages are x86_64 today, and when an arm64 one appears its probe must ask
-- for AArch64 rather than silently accept an x86-64 entry.
local ABI_TOKENS = {
    x86_64  = "x86-64",
    aarch64 = "AArch64",
}

-- The fallback directories, covering all three layouts.
--
-- Order is multiarch, then biarch, then the plain one -- but the order is NOT
-- what makes this correct. Rule 2 is: every candidate is ELF-class checked, so
-- Fedora's 32-bit /usr/lib is REJECTED rather than merely sorted last. The
-- order only decides between two equally valid answers.
local function default_dirs(arch)
    local triplet = (arch == "aarch64") and "aarch64-linux-gnu"
                                        or  "x86_64-linux-gnu"
    return {
        "/usr/lib/" .. triplet,   -- Debian / Ubuntu multiarch
        "/lib/" .. triplet,       -- ditto, pre-usrmerge spelling
        "/usr/lib64",             -- FHS biarch: Fedora / RHEL / SUSE
        "/lib64",
        "/usr/lib",               -- Arch / Gentoo (64-bit); Fedora (32-bit!)
        "/lib",
    }
end

-- Every host directory that holds a 64-bit SONAME, in resolution order.
--
-- Returns a list rather than one answer, because two callers want different
-- things from the same probe: `dir_of` wants the first, and a caller building
-- a search path may want all of them. Both get rule 2 applied.
--
-- opt.arch       target architecture (default: x86_64)
-- opt.extra_dirs searched BEFORE the defaults, for a layout only the caller
--                knows about (`/usr/lib/wsl/lib`). Still ELF-class checked --
--                a caller-supplied path is not a trusted path.
function hostlib.dirs_of(soname, opt)
    opt = opt or {}
    local arch  = opt.arch or "x86_64"
    local want  = ABI_TOKENS[arch]
    local class = 64
    local out, seen = {}, {}

    local function push(dir)
        if dir and dir ~= "" and not seen[dir] then
            seen[dir] = true
            table.insert(out, dir)
        end
    end

    -- RULE 1 -- the loader's own index.
    --
    -- Parsed for the ABI token as well as the name: on a biarch host both the
    -- 32- and 64-bit entries are present under one soname, and taking the
    -- first line is how you get a 32-bit answer from an authoritative source.
    local listing = try {
        function() return os.iorun("ldconfig -p 2>/dev/null") end
    }
    if listing and listing ~= "" then
        for line in listing:gmatch("[^\n]+") do
            if line:find(soname, 1, true)
               and (not want or line:find(want, 1, true)) then
                local p = line:match("=>%s*(/%S+)")
                -- Verified on disk, not merely listed: the cache outlives the
                -- files it names, and a stale entry is exactly the shape that
                -- makes a probe succeed and the dlopen fail.
                if p and os.isfile(p) and hostlib.elf_class(p) == class then
                    push(path.directory(p))
                end
            end
        end
    end

    -- RULE 2 + the fallback. Reached on a host with no populated ld.so.cache
    -- (minimal containers) and for a caller-supplied layout.
    local dirs = {}
    for _, d in ipairs(opt.extra_dirs or {}) do table.insert(dirs, d) end
    for _, d in ipairs(default_dirs(arch))   do table.insert(dirs, d) end
    for _, d in ipairs(dirs) do
        local p = path.join(d, soname)
        if os.isfile(p) and hostlib.elf_class(p) == class then push(d) end
    end

    return out
end

-- The directory holding the host's SONAME, or nil.
--
-- RULE 3 -- first hit. `nil` means "this host does not have it", which for
-- every caller in this index is a normal state to be reported, not an error to
-- be worked around by guessing.
function hostlib.dir_of(soname, opt)
    local dirs = hostlib.dirs_of(soname, opt)
    return dirs[1]
end

function hostlib.path_of(soname, opt)
    local d = hostlib.dir_of(soname, opt)
    return d and path.join(d, soname) or nil
end

-- Every file in DIR whose name starts with one of PREFIXES, 64-bit only.
--
-- Enumerated rather than listed by the caller for the reason
-- nvidia-gl-host-link enumerates: the private halves of a driver carry the
-- driver version in the SONAME, so a fixed list is a list of one release. And
-- ELF-class filtered for the reason above -- a 32-bit sibling in the same
-- directory (Fedora ships both) must not be linked into a 64-bit payload.
function hostlib.entries_with_prefix(dir, prefixes)
    local names = {}
    if not dir or not os.isdir(dir) then return names end
    local f = io.popen(string.format([[ls -1 "%s" 2>/dev/null]], dir))
    if not f then return names end
    for line in f:lines() do
        local name = line:gsub("[\r\n]+$", "")
        if name ~= "" then
            for _, p in ipairs(prefixes) do
                if name:find(p) then
                    local full = path.join(dir, name)
                    -- A symlink is followed by elf_class, which is what we
                    -- want: the link's target decides, and a dangling link
                    -- answers nil and is dropped.
                    if hostlib.elf_class(full) == 64 then
                        table.insert(names, name)
                    end
                    break
                end
            end
        end
    end
    f:close()
    return names
end

-- Where this distribution WILL put a 64-bit library that is not installed yet.
--
-- The one question in this module that cannot be probed, and therefore the one
-- place a layout table is legitimate: a sentinel that links to a driver the
-- user has not installed yet needs a path that will become correct later
-- (`libcuda-host-link`'s self-heal case). There is no file to read the ELF
-- class of, so `/etc/os-release` is the only evidence available.
--
-- Kept HERE rather than in that recipe so the layout knowledge still lives in
-- exactly one file -- which is what lets the CI invariant ("no recipe
-- enumerates distro library directories") have no exceptions.
--
-- Answers a DIRECTORY. The caller joins the soname, so this cannot drift from
-- dir_of's contract.
function hostlib.canonical_libdir(arch)
    arch = arch or "x86_64"
    local triplet = (arch == "aarch64") and "aarch64-linux-gnu"
                                        or  "x86_64-linux-gnu"
    if os.isfile("/etc/os-release") then
        local content = io.readfile("/etc/os-release") or ""
        local idl = ((content:match("ID=([^\n]*)") or "") .. " " ..
                     (content:match("ID_LIKE=([^\n]*)") or "")):lower()
        idl = idl:gsub('"', '')
        if idl:find("debian") or idl:find("ubuntu") or idl:find("mint") then
            return "/usr/lib/" .. triplet
        elseif idl:find("fedora") or idl:find("rhel") or idl:find("centos")
            or idl:find("opensuse") or idl:find("suse") then
            return "/usr/lib64"
        elseif idl:find("arch") or idl:find("manjaro") then
            return "/usr/lib"
        end
    end
    -- The multiarch default, and it is a default rather than a guess for one
    -- reason: on a biarch host it is simply absent, so a link pointing there
    -- stays dangling and visibly does nothing -- whereas defaulting to
    -- /usr/lib would, on that same host, resolve to the 32-BIT directory and
    -- produce `wrong ELF class` from a link that looks correct.
    return "/usr/lib/" .. triplet
end

-- Say what was found, once, in the form a reader can act on.
--
-- Separate from the probe so a caller that legitimately expects nothing (a
-- sentinel on a host without that driver) does not print a scary line, and one
-- that expected something can say so in its own words.
function hostlib.report(soname, dir)
    if dir then
        log.info("host %s -> %s", soname, dir)
    else
        log.warn("host %s not found (ldconfig -p and the three standard "
                 .. "layouts were checked, 64-bit only)", soname)
    end
end

return hostlib
