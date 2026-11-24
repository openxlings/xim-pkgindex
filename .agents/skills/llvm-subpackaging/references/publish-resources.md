# xlings-res Resource Publishing SOP (llvm sub-packages, dual mirrors)

Asset repository: `xlings-res/llvm` (the same repository, archived by tag=version number).
- `GLOBAL` = https://github.com/xlings-res/llvm
- `CN`     = https://gitcode.com/xlings-res/llvm

The two mirrors **must contain exactly the same assets**, otherwise the xpkg cannot be switched to that version.

## 1. Asset naming convention

```
<pkg>-<version>-<platform>-<arch>.<ext>
```
- `<pkg>`: `llvm` | `llvm-tools` (2-package model; there is no core/libcxx any more)
- `<platform>-<arch>`: `linux-x86_64` | `macosx-arm64` | `windows-x86_64`
- `<ext>`: linux=`tar.gz`+`tar.xz`, macosx=`tar.xz`, windows=`tar.xz`+`zip` (aligned with the live assets;
  the two packages of the same platform and version use the same extensions)

Examples: `llvm-22.1.8-macosx-arm64.tar.xz`, `llvm-tools-22.1.8-windows-x86_64.zip`

## 1.5 Admission acceptance (mandatory before upload, Linux `llvm` package)

```bash
.agents/tools/verify-toolchain.sh <llvm-*.tar.gz> \
  --loader ~/.xlings/data/xpkgs/xim-x-glibc/2.39/lib64/ld-linux-x86-64.so.2
```

The script has a built-in **llvm gate**; anything that fails is never uploaded:
1. **Missing parts**: `share/libc++/v1/std.cppm`, `libc++.so*`, `libatomic.so.1`
   (historical incident: the slim carve missed libatomic → every artifact hung at runtime with
   `libatomic.so.1: cannot open`, discovered by users);
2. **hermetic CRT**: a `-###` dry run asserts that `Scrt1.o/crti.o/crtn.o` all resolve into the
   glibc payload (`-B`), not onto the host `/lib`, and not as bare names (the mcpp issue #195 class of environments);
3. **import std end to end**: precompile std.cppm → compile and link → run.

## 2. Publish commands

### GLOBAL (GitHub, overwrite supported)

```bash
# when the release already exists:
gh release upload <tag> <file>... --clobber --repo xlings-res/llvm
# when the release does not exist, create it first:
gh release create <tag> --repo xlings-res/llvm --title <tag> --notes "llvm <tag> sub-packages"
```

### CN (GitCode)

```bash
# for a new tag, create the release first:
gtc release create xlings-res/llvm --tag <tag> --name "LLVM <tag> (split packages)"
# upload (new asset names are uploaded directly):
gtc release upload xlings-res/llvm --tag <tag> <file>...
```
> **gtc cannot delete assets**, nor overwrite assets of the same name. To replace an old asset with the same name, **the maintainer
> manually deletes it on the GitCode web page** and then runs `gtc release upload`. New asset names (e.g. a new platform/new version) need no deletion; upload directly.

For the location and configuration of `gtc`, see the reference memo (`/home/speak/.local/bin/gtc`,
token in `~/.config/gitcode-tool/config.json`).
`gtc release create` may return HTTP 400; fall back to creating the release directly via the GitCode API (see the memo).

## 3. sha256 three-way verification (mandatory after publishing)

```bash
sha256sum <file>                                  # carve output
curl -sL <GLOBAL_url> | sha256sum                 # GitHub RES
curl -sL <CN_url>     | sha256sum                 # GitCode RES
# all three must be exactly identical
```

URLs look like:
```
https://github.com/xlings-res/llvm/releases/download/<tag>/<asset>
https://gitcode.com/xlings-res/llvm/releases/download/<tag>/<asset>
```

## 4. Pre/post-publish checklist

- [ ] Every sub-package asset for all three platforms is uploaded to **both GLOBAL and CN**, naming compliant.
- [ ] Every asset's sha256 is consistent three ways (carve / GLOBAL / CN).
- [ ] When backfilling an old version, `latest` on both sides still points to the version that should be newest (no going backwards).
- [ ] Xpkg has `sha256 = nil`, so same-name replacement needs no xpkg change; if some xpkg pins a sha256, update it in sync.
- [ ] State the GLOBAL/CN tag and sha256 results clearly in the PR/report (required by `xpkg-creater` §1.2.1).

## 5. Relationship to existing mechanisms

- The asset path uses the same resource service as "index repository distribution (Y-asset)", but they are different assets and must not be confused
  (see `xpkg-creater` §1.2.1 and `docs/11-official-resources.md`).
- The way a same-name replacement goes live is the same as the toolchain strip repackaging (see the "how to go live" section of
  `.agents/docs/2026-06-22-toolchain-strip-plan.md`).
