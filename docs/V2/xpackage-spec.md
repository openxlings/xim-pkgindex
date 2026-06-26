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

Requires **xlings ≥ 0.4.61** (libxpkg ≥ 0.0.42). Older clients ignore the new
shapes; keep a V1 fallback entry if you must support them.

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

## Resolution order (install time, on the host)

1. follow version `ref` (e.g. `latest → 4.0.2`) — unchanged;
2. **Shape B**: pick `archs[host_arch]` → `{url, sha256}` (fail-closed);
3. **res**: build the `XLINGS_RES` URL + `sha256[host_arch]` (fail-closed);
4. **Shape C**: expand the template with the host arch + `sha256[host_arch]` (fail-closed);
5. otherwise the V1 single-arch path (`url`/`sha256`/`XLINGS_RES`) — unchanged;
6. mirror (`GLOBAL`/`CN`) selection applies **after** the arch pick.

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
