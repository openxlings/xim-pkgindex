# XPackage Spec V2

> `spec = "2"` — adds **multi-architecture** package description.
> V2 is a strict superset of [V1](../V1/xpackage-spec.md): every V1 recipe is a
> valid V2 recipe. Only the additions are documented here; for everything else
> (base fields, hooks, libxpkg stdlib, `XLINGS_RES`, mirror tables) see V1.

## Why V2

In V1, `xpm` resolved a download by **platform + version** only. Architecture
was a flat `archs = {...}` metadata list that was **never used** during URL
resolution and **never validated**. Recipes that shipped one URL per platform
silently served the same binary to every CPU arch — e.g. a recipe declaring
`archs = {"x86_64", "aarch64"}` but hard-coding an `amd64` URL would install a
broken binary on ARM. V2 makes architecture a **first-class, declarative,
install-time-resolved** dimension, with a mandatory per-arch checksum.

Requires **xlings ≥ 0.4.63** (libxpkg ≥ 0.0.45) for the complete `xpm.source`
and compat contract. The per-architecture shapes were introduced earlier and
remain compatible with xlings 0.4.61+. Older clients ignore new fields or may
misinterpret root/platform `source`; keep the legacy entry form when the same
index must be consumed by those clients.

## Arch names (canonical + aliases)

Use the **canonical** spelling in `archs` and in arch keys. Aliases are
accepted on input and normalized:

| Canonical | Accepted aliases |
|-----------|------------------|
| `x86_64`  | `amd64`, `x64`, `x86-64` |
| `aarch64` | `arm64`, `armv8` |
| `x86`     | `i386`, `i686` |

Resolution and `archs` validation are **fail-closed**: if the host arch is not
provided by the entry (and `archs` is non-empty and excludes it), the install
aborts with a clear error instead of fetching a wrong binary.

## The three new version-entry shapes

A version entry value may now be, in addition to the V1 forms
(`"XLINGS_RES"`, `"url-string"`, `{ url=, sha256=, ref= }`):

### Shape B — per-arch resource map

Each arch carries its own `url` (string or `{GLOBAL=,CN=}` mirror table) and
`sha256`. Best when upstream URLs are irregular.

```lua
["2.86.0"] = {
    x86_64  = { url = "https://.../gh_2.86.0_linux_amd64.tar.gz", sha256 = "..." },
    aarch64 = { url = "https://.../gh_2.86.0_linux_arm64.tar.gz", sha256 = "..." },
}
```

### Shape C — URL template + per-arch sha256

One `url` template covers all arches; `sha256` becomes a per-arch table.
Placeholders: `${name}` `${version}` `${os}` (`linux`/`macosx`/`windows`)
`${arch}` (canonical) `${arch_alias}` (mapped via the optional `arch_alias`
table) `${ext}` (`zip` on windows, else `tar.gz`). Best when URLs are regular.

```lua
["1.0.0"] = {
    url = "https://ex/${name}-${version}-${os}-${arch_alias}.${ext}",
    sha256 = { x86_64 = "aaaa...", aarch64 = "bbbb..." },
    arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },  -- optional
}
```

### Shape res — `XLINGS_RES` with per-arch checksums

The V1 `"XLINGS_RES"` magic string auto-generates a URL but carries **no
checksum**. The `res` shape closes that gap: same auto-URL, now with a
mandatory per-arch `sha256`.

```lua
["4.0.2"] = {
    res = true,
    sha256 = { x86_64 = "aaaa...", aarch64 = "bbbb..." },
}
```
Auto-URL pattern (unchanged from V1 `XLINGS_RES`):
`{res-server}/{name}/releases/download/{version}/{name}-{version}-{os}-{arch}.{ext}`

### Shape source — shared default source (recommended)

`xpm.source` keeps the original platform/version matrix and removes repeated
URLs or repeated `"XLINGS_RES"` values. It can be declared at the root or on a
platform; the platform value overrides the root value. Supported values are
`"xlings-res"`, an HTTP(S) URL template, or a regional source map. In a map,
`GLOBAL` is the canonical upstream and other keys are equivalent-byte fallback
mirrors:

```lua
source = {
    GLOBAL = "https://github.com/acme/foo/releases/download/${version}/foo-${arch_alias}.${ext}",
    CN = "https://gitcode.com/xlings-res/foo/releases/download/${version}/foo-${arch_alias}.${ext}",
},
```

The same map shape is valid at platform scope. Version entries only need to
carry the checksum when the URL shape is stable. xlings selects the requested
region first and retains the other regions as fallback candidates; mirror
assets must be byte-identical.

```lua
xpm = {
    source = "xlings-res",
    linux = {
        ["latest"] = { ref = "1.0.0" },
        ["1.0.0"] = {
            sha256 = { x86_64 = "<x86-hash>", aarch64 = "<arm-hash>" },
        },
    },
}
```

For a regular third-party release:

```lua
xpm = {
    source = "https://github.com/acme/foo/releases/download/${version}/foo-${os}-${arch_alias}.${ext}",
    linux = {
        ["1.0.0"] = {
            arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
            sha256 = { x86_64 = "<amd64-hash>", aarch64 = "<arm64-hash>" },
        },
    },
}
```

An explicit version `url` always overrides `source`; mirror tables, `ref`,
single hashes and per-arch resource maps remain valid. `res = true` is a
legacy input for the same official resource URL and should not be added to new
recipes.

## Resolution order (install time, on the host)

1. follow version `ref` (e.g. `latest → 4.0.2`) — unchanged;
2. pick a per-arch resource map → `{url, sha256}` (fail-closed);
3. use explicit version `url`/hash;
4. use platform `source`, then root `source`;
5. expand `xlings-res` or URL templates and select the host-arch hash;
6. otherwise use the V1 single-arch path (`url`/`sha256`/`XLINGS_RES`);
7. mirror (`GLOBAL`/`CN`) selection applies **after** resource normalization.

The index keeps the **raw, arch-agnostic** data; arch is resolved per-host at
install time (so a single shared index artifact serves every arch).

## Install hooks must be arch-aware too

If a recipe unpacks an arch-named directory, derive it from `os.arch()` in the
hook (don't hard-code one arch). `os.arch()` returns the canonical host arch.

```lua
function install()
    local dir = string.format("gh_%s_%s_%s", pkginfo.version(), os.host(), os.arch())
    -- ... move dir into pkginfo.install_dir()
end
```

## `subos.env` — declaring an environment a subos must export

Requires **libxpkg ≥ 0.0.48**. Probe it (see the next section) — and probe it
with `type()`, because it arrives as a new module.

Some things a program needs cannot be linked or PATH'd into place. A GL driver
is found through `LIBGL_DRIVERS_PATH`, an EGL vendor through
`__EGL_VENDOR_LIBRARY_DIRS`, a font config through `XDG_DATA_DIRS`. The process
that has to see them is the *user's own binary*, which xlings never wraps, so
the per-shim `envs` on `xvm.add` cannot reach it.

```lua
import("xim.libxpkg.subos")

function config()
    if type(subos.env) == "function" then
        local tag = package.name .. "@" .. pkginfo.version()
        subos.env{ var = "LIBGL_DRIVERS_PATH", op = "set",
                   value = "${pkgdir}/lib/dri", binding = tag }
        subos.env{ var = "XDG_DATA_DIRS", op = "prepend",
                   value = "${pkgdir}/share", binding = tag }
    end
    return true
end
```

| field | required | meaning |
|---|---|---|
| `var` | ✅ | variable name |
| `op` | | `set` (default) or `prepend`. `append` / `set-if-unset` are not implemented and are **refused**, not silently downgraded |
| `value` | ✅ | may contain the placeholders below |
| `binding` | | `<name>@<version>`; defaults to this package's. Declaring for another package is refused |

**Values must use placeholders.** They are expanded when the subos is entered,
and a literal absolute path pins the manifest to the machine that wrote it:

| placeholder | expands to |
|---|---|
| `${pkgdir}` | the declaring package's install directory |
| `${subosdir}` | the subos root |
| `${home}` | the user's home |
| `${xlings_home}` | `$XLINGS_HOME` |

An unresolvable placeholder is left **verbatim** rather than blanked —
`${pkgdir}/lib/dri` collapsing to `/lib/dri` would be a real path on the host,
outside the subos. `xlings self doctor` reports it.

**Do not write cleanup in `uninstall()`.** Declarations are provider-scoped:
xlings drops the whole section with the package. A recipe removing them itself
would be a second owner of that state.

Conflicts (two packages claiming one variable) resolve deterministically by
binding order, never by install history, so two machines holding the same
manifest export the same values. `doctor` reports every conflict rather than
resolving it quietly. A variable the **user** already exported wins over a
`set`; `prepend` still composes with it.

## `resolved_deps` — what the resolver decided, for hooks that need it

A recipe writes a dependency as a **question**:

```lua
deps = { "xim:glibc@>=2.38" }
```

`_RUNTIME.resolved_deps` is the **answer**, available in `install()` and
`config()` from xlings 2026.8.5.3 / libxpkg 0.0.50:

```lua
_RUNTIME.resolved_deps["xim:glibc@>=2.38"] = {
    name        = "xim:glibc",
    version     = "2.44",                      -- what it resolved TO
    install_dir = "<store>/xpkgs/xim-x-glibc/2.44",
    libdirs     = { "<store>/xpkgs/xim-x-glibc/2.44/lib64" },
    source      = "plan-range",                -- why this one
}
```

**Total, unlike `deps_exports`.** Every runtime dep is here whether or not it
declared `exports`. A dep missing from this table means the CLIENT does not
send it, not that the dep declared nothing — those two used to be
indistinguishable, and telling them apart is the point.

### Use it instead of looking a dependency up yourself

`pkginfo.dep_install_dir(name)` consults this table first, so most recipes need
nothing new. What a recipe must NOT do is re-derive the answer:

```lua
-- WRONG: a second answer to a question that already has one.
local dir = "<...>/xpkgs/xim-x-glibc/" .. some_version .. "/lib64"

-- WRONG: also a second answer, just spelled with an API.
for _, sub in ipairs({"lib64", "lib"}) do ... end
```

Both were real code. With two versions of a package installed they answered
differently from the resolver, and the product was a binary whose interpreter
came from one payload and whose RUNPATH from another — a fault before `main`
reporting `undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE`,
which names neither package nor version.

xlings now refuses to finish an install that produced one, and `xlings doctor`
reports existing ones. Design and the invariant:
`xlings/.agents/docs/2026-08-05-dependency-resolution-single-source.md`

### Probing for it

```lua
if type(_RUNTIME.resolved_deps) == "table" then
    -- use it
end
```

`type()`, never `if _RUNTIME.resolved_deps then`. See the next section — the
same trap applies to every capability added after a client shipped.

### Inspecting it after the fact

Each install writes `<install_dir>/.xlings-resolution.json`, and

```
xlings why <package> [dependency]
```

reads it back: the version, the payload, and `source`. That is what makes
"why is it 2.39 on this machine" answerable without reproducing the machine.

---

## Adopting a capability older clients do not have

The index serves every client version at once. Two kinds of change behave very
differently:

- **A new field on an existing shape is safe.** Unknown keys are read with
  `j.value(key, default)` and ignored, which is why `spec = "2"` could ship as
  a plain opt-in.
- **A new xvm node kind is not.** An older xlings validates the kind against a
  whitelist and aborts the whole registration:

  ```
  error: unsupported registration node kind 'files'
         nothing was changed
  ```

There is no `min_xlings` in this index, so an old client cannot be served an
old recipe. Adopt the capability **in the recipe**, by probing for it:

```lua
if xvm.files then
    xvm.files{ src = "include/openssl", dst = "usr/include/openssl", binding = tag }
else
    sysroot.install_headers(includedir, get_sys_usr_includedir())  -- unchanged
end
```

**Probe the capability, never the version.** libxpkg is statically linked into
the xlings binary, so the Lua function and the C++ that consumes its node kind
ship together: "is `xvm.files` a function" *is* "does this client support
`type = files`". One truth source, nothing to keep in sync.

#### A new module needs `type()`, not truthiness

`if xvm.files then` is correct **only because `xvm` is a module older clients
already ship.** The field really is `nil` there. A missing *module* never is:

```lua
import("xim.libxpkg.subos")     -- a client without it gets a STUB
if subos.env then               -- ← true on EVERY client. Wrong.
```

`import()` answers an unknown module with a permissive proxy whose every key
returns a truthy, callable table. The old client takes the new branch, calls
the function, and the call evaporates — install succeeds, nothing is
configured, nothing complains.

For a capability introduced as a **new module**, probe the type:

```lua
if type(subos.env) == "function" then
    subos.env{ var = "LIBGL_DRIVERS_PATH", op = "set",
               value = "${pkgdir}/lib/dri", binding = tag }
else
    -- unchanged legacy path
end
```

The stub is a `table` carrying a `__call` metamethod; the real entry point is
a `function`. That is the only thing that separates them.

| the capability is… | probe |
|---|---|
| a new function on an existing module (`xvm.files`) | `if xvm.files then` |
| a new module (`subos.env`) | `if type(subos.env) == "function" then` |

xlings E2E-61 runs one recipe through a real released binary and the current
build and asserts both readings — truthiness `true` on both, `type()` `false`
then `true`. If `import()` ever stops stubbing unknown modules, that test is
what says the rule can be relaxed.

Rules:

1. **Probe the new function name.** `xvm.add{type = "files"}` does not work --
   `xvm.add` exists on old clients and passes `type` straight to the whitelist.
2. **The legacy branch stays byte-identical.** It is the old client's only
   path, and it has no test coverage of its own.
3. **Branch in `uninstall()` too.** The legacy path keeps its hand-written
   cleanup; the declared path leaves removal to provider-scoped deregistration,
   or the same files end up with two owners.
4. **Verify against a real old binary.** `import()` returns a permissive proxy
   stub for unknown modules, so a module resolved that way would make the probe
   truthy everywhere and silently useless. xlings E2E-37 runs one recipe
   through a downloaded 0.4.69 and the current build.
5. **Compare the old-client result differentially.** Many recipes guard their
   copy on `os.isdir(sysroot/usr/include)`, which does not exist in a fresh
   home -- the *unmigrated* recipe places nothing either. Assert "same as
   before the migration", not "the file is there".

The probe is removed when the index drops support for clients older than the
capability. That is a decision about shrinking the support surface, not a
prerequisite for shipping.

### Dropping the probe later — and why there is no `min_xlings`

A probe is temporary by design. Removing one means the recipe declares the
capability unconditionally, and clients without it stop being able to install
the package. Before doing that, the package needs a way to *tell* those
clients why.

**A `min_xlings` field cannot do it.** A field is only read by clients that
implement it, and the clients that need to be told are exactly the ones that
do not. A version floor expressed as index data can never reach them; they
would still hit the raw failure:

```
error: unsupported registration node kind 'files'
       nothing was changed
```

The mechanism that does reach them is one they already run: `raise` from
`config()`. Every client back to 0.4.29 prints it verbatim.

```lua
sysroot.require_capability(xvm.files, "xvm.files", "2026.7.27.0")
```

```
[warn] config hook failed for foo: foo.lua:16: this package needs
       xlings >= 2026.7.27.0 (this client has no xvm.files); run: xlings self update
[error] [foo] failed: config hook failed
```

So the sequence for retiring a probe is:

1. the capability has been released long enough for adoption;
2. replace `if cap then ... else <legacy> end` with
   `sysroot.require_capability(cap, ...)` plus the declared path;
3. the legacy branch goes away, and clients that cannot install the package
   are told what to do instead of being confused.

`config()` runs after download and extraction, so step 2 costs a refused
client one download. That is deliberate: a message they can act on is worth
more than a field they cannot read.

