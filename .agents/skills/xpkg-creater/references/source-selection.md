# Choosing the source, the mirror and the linking

## 1. Source order

Take the first that has what you need for each platform and architecture:

| Tier | What | Notes |
|---|---|---|
| 1 | The upstream project's own release (its site, its CDN) | Vendor downloads, official appcasts |
| 1 | The upstream project's official repository release | `github.com/<org>/<project>/releases` of the project itself |
| 2 | A well-known third-party release | Widely used, stable, named maintainers, checksums published (a distro-independent static build, a big packaging project) |
| 3 | Resources the maintainers host on `xlings-res` | Written by maintainers (who have the access). A contributor asks in an issue; do not self-serve |

Do not mix tiers inside one version to fill gaps silently: if platform A is official and B
only exists third-party, say so in the package note and the PR.

A resource with no checksum from its source is still usable: compute the sha256 from the
bytes you downloaded, download a second time (ideally from a second network path) and compare.
Never copy a hash from a place that is not the source of the bytes.

## 2. Mirrors

- **GLOBAL** is the upstream URL (tier 1 or 2); `xlings-res` (tier 3) only when neither can serve.
- **CN**: prefer a well-known institutional mirror (USTC `mirrors.ustc.edu.cn`, Tsinghua, ...)
  that mirrors the *original* upstream files. Check the real path (do not guess it from the
  domain), that every asset you need is there, and that its sha256 equals GLOBAL's. A redirect
  back to GitHub is not a CN resource.
- **No well-known CN mirror**: declare `ci = { mirror = true }`. After merge CI copies the GLOBAL
  bytes to `xlings-res`; users fetch that copy only once a `CN` leg points to it, and a maintainer
  adds that leg later (`docs/13-ci-mirror-and-update.md`). A maintainer with `xlings-res` access may
  write the CN resource in the same pull request (`maintainer-publishing.md`). Never invent a mirror path.
- The user's client tries its region first and falls back to the other, and the xpkg's
  sha256 decides what is accepted, so a stale mirror is refused, not trusted.

## 3. Linking: static and musl preferred, inside the official source

Order of preference for a Linux binary, **within the best source tier available**:

1. A fully static artifact (musl-static, a Go or Rust static binary).
2. A dynamic glibc artifact whose requirements you declare: `xim:glibc` and every library its
   `DT_NEEDED` names (`readelf -d`, `LD_TRACE_LOADED_OBJECTS=1 <bin>`). Run the program once.

"Official beats musl": if the upstream only ships a dynamic glibc build, use it. Do not
replace it with a third-party musl build. If a general, official static build does not exist
and a musl one would be valuable, open an issue; building one is the maintainers' resource
factory (`tools/res/`), never the xpkg's.

A payload that finds its own libraries through `$ORIGIN` (Electron-style, xPack) declares no
loader dependency: declaring `xim:glibc` would make elfpatch replace its `DT_RPATH`.

### Closing the dependencies

An xpkg's dependencies close **inside the xlings ecosystem**: every library its payload loads and
every tool its hooks run is a declared `xim:` dependency (`xim:glibc`, `xim:gcc-runtime`,
`xim:vcruntime`, a toolchain) or is carried by the payload itself. The index tests what it
declares; it cannot test what happens to be on a user's machine, and a host library is not the one
xlings relocated the payload against.

- A dynamic glibc payload declares `xim:glibc` plus the libraries `readelf -d` names. A comment
  such as "runs against the host's glibc >= 2.14" is **not** a reason to declare nothing: it makes
  the install depend on a machine the index never ran on (a musl host, a minimal container, an old
  distribution) and the program starts or not by luck.
- A hook uses `xim.libxpkg.*` and the `libs/` modules. A host command is the platform's own base
  tool (`tar`, `chmod`, `sh` on POSIX; `%SystemRoot%\System32\tar.exe` on Windows) and nothing
  beyond that without a reason; never a host package manager.
- A reason that **is** strong: the thing cannot be shipped and must belong to the machine, such as
  the GPU driver stack (`libs/hostlib.lua` resolves it the way the loader would), a kernel
  interface, or a licence that forbids redistribution. State which one, in the header comment of the
  xpkg ("Host: <what>, because <why>") and in the pull request, so a reviewer can accept or refuse
  it. Convenience, a smaller diff, or "the CI runner has it" are not reasons.
- If no `xim:` package provides what you need, say so in the pull request and open an issue for the
  missing package; do not paper over it with the host's copy.

## 4. No compiling at install

`install()` never runs `configure`, `cmake`, `make`, `cargo`, `go build` or a compiler. It
unpacks, places and (for a Linux prebuilt ELF) relocates. A package that exists only as source
is not an xpkg here: open an issue, and a maintainer can have the resource factory build it.

`install()` also should not resolve a language runtime's dependency tree from the network
(`pip install`, `npm install` of an unpinned tree) unless the upstream's own lockfile and a
declared toolchain (`xim:uv`, `xim:pnpm`, `xim:node`) are what does it; declare every
platform's toolchain, and do not fall back silently to the host's.

## 5. Namespaces: official vs unofficial

| Case | Namespace | Hosted where |
|---|---|---|
| Upstream's own release, repackaged by nobody | none (`xim:<name>`) | Upstream |
| An official xim package a maintainer builds | none | `xlings-res` (maintainers) |
| A repack, a patched or rebuilt build, anything a person maintains | `namespace = "<your handle>"` in `package` | Your repository or release |

- The id becomes `<ns>:<name>@<version>`; it never collides with, and is never mistaken for,
  the upstream-based package.
- Do not take a reserved namespace (`xim`, `luban`, `subos`, `config`).
- In the pull request and the package note give the **source** (what you started from, with
  its hash) and a **reproducible process** (the exact commands, tool versions and inputs), so
  a reviewer can rebuild the asset and compare the sha256.
- A package that many users would want, but whose asset you had to build: open an issue asking
  maintainers to host it on `xlings-res`. If accepted, a maintainer republishes it and the
  xpkg moves to `xim:` without a prefix.
- Precedent: `pkgs/t/tinynext.lua`, `pkgs/c/clash-flux.lua`, `pkgs/l/llm-switch.lua`
  (`namespace = "farnaherry"`).
