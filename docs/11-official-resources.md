# Official Resources

**English** | [简体中文](zh/11-official-resources.md)

The binaries this index installs from its own servers: where they live, how they
are built, and the gates a release passes before a recipe names it.

## Where they live

`xpm.source = "xlings-res"` resolves to the official resource servers, one
organisation on two hosts with byte-identical content:

| Region | Server |
|---|---|
| `GLOBAL` | `https://github.com/xlings-res` |
| `CN` | `https://gitcode.com/xlings-res` |

A resource is `xlings-res/<package>`, a release per version, assets named
`<name>-<version>-<os>-<arch>.<ext>` with a `.sha256` sidecar. A client tries its
region first and keeps the other as a fallback; the sha256 in the recipe decides
what is accepted, so a lagging mirror is refused, never trusted.

Index artefacts (`xlings-res/xim-index`) are a separate kind of resource with
their own pointers; a package's binaries never go there, and an index never goes
into a package's release.

## Mirrored or built

| Kind | Example | How it gets there |
|---|---|---|
| mirrored | a third-party release with `ci.mirror = true` | the mirror workflow verifies and copies it ([CI](13-ci-mirror-and-update.md)) |
| built here | bwrap, pasta, e2fsprogs, limine, qemu-system, gcc for aarch64 | the resource factory, `tools/res/` |

## The resource factory

`tools/res/build.sh <what> <version> <out>` builds one resource on the
architecture it is for. The `res-build` workflow runs it on `ubuntu-24.04` and
`ubuntu-24.04-arm`:

- everything it needs runs in a container **pinned by digest** (Alpine for
  static musl builds, Debian for what links glibc); the runner needs only docker;
- every upstream input is checked against the digest in `tools/res/inputs.txt`;
- every build checks what it made — it runs, it is static where it says so, it
  needs only glibc where it links it, it holds no hard link — before it is an
  artifact;
- each payload carries a `README.provenance`: its inputs, their digests, the
  container, and the packages installed inside it.

```bash
gh workflow run res-build.yml --ref <branch> -f only=qemu-system
gh workflow run res-build.yml --ref <branch> -f publish_runs="<run-id>" -f execute=true
```

The first builds one resource on a branch; the second publishes the artifacts of
runs already made, in the protected `xlings-res-publish` environment.

**Self-hosting is the direction, not yet the state.** Inside the factory's
containers, build tools come from the distribution's package manager (Alpine's
`apk`, Debian's `apt`). The goal is a factory whose tools are themselves
installed from this index by xlings, so that every resource is built only from
things this ecosystem publishes; until then the container digest and
`README.provenance` record exactly what was used.

## The gates

A resource is named by a recipe only after all of these hold:

1. **Every platform and architecture** the recipe claims has an asset, on GitHub
   and on GitCode, with the same name.
2. **One build is the authority**: the sha256 is computed from it, then each copy
   (upstream, GitHub, GitCode) is downloaded and compared byte for byte. GitCode
   is verified with GET, not HEAD (it answers HEAD with 401).
3. **The `.sha256` sidecar exists** for every asset; `version-check.py --apply`
   fails, changing nothing, when a supported architecture's hash is missing.
4. **`latest` moves only to a verified version**, and never backwards when an
   older version is added.
5. **A published resource never changes.** A rebuild (a patch, a prefix, a layout
   fix, a hard link removed) is published under a new tag and asset name,
   `<version>-r<N>`, and the version entry's `revision` becomes N. The old asset
   stays as it is: a client with a cached index still holds its hash.
   `.github/scripts/check-revision.lua` refuses a changed resource without a
   higher revision. A rebuild that fixes a defect every installed payload has
   also raises the entry's `floor` to N; one that does not (a hard link
   removed, a layout change for one platform) leaves it, and installed payloads
   keep working ([`floor`](specs/xpackage-v2.md#floor--the-oldest-installed-revision-still-usable)).

## The xlings release

A new xlings release is installable once `pkgs/x/xlings.lua` names it: every
platform's entry for the new version with its sha256, and `latest` moved to it.
The release's assets are on GitHub and GitCode first (the GitCode copy is pushed
from a CN machine); the index change merges after both are verified.
