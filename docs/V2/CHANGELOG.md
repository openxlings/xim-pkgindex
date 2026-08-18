# XPackage V2 — Change Log

Records the schema change and the per-recipe version/arch-coverage changes
introduced with **XPackage Spec V2 (multi-arch)**. Requires **xlings ≥ 0.4.61**
(libxpkg ≥ 0.0.42).

## Schema

- `spec = "2"`: architecture is now a first-class, install-time-resolved
  dimension. New version-entry shapes: per-arch map (B), URL template +
  per-arch sha256 (C), and `res = true` + per-arch sha256. Arch names are
  normalized (`arm64↔aarch64`, `amd64↔x86_64`). `package.archs` is now
  validated fail-closed. See [`xpackage-spec.md`](./xpackage-spec.md).

## Tooling fixes

- **`arch_alias` + `ci.mirror` was unusable in the documented field order**
  (2026-08-19). `tools/xpkg_ci.py` read the per-version aliases with a scan
  over the whole version body, and `sha256` is a per-arch table of the same
  `<arch> = "<string>"` shape — so the later table won. In the order this spec
  documents (`arch_alias` first, then `sha256`, see
  [`xpackage-spec.md`](./xpackage-spec.md) §"Shape C"), every alias resolved to
  a checksum and the mirror built `...-linux-7cd69277….tar.gz`. Alias
  extraction is now scoped to the `arch_alias = { … }` block, so field order no
  longer matters. Nothing in the index carried both an `arch_alias` and
  `ci.mirror` until `qemu-riscv`, which is why it never fired.
- **The version bumper could move `["latest"]` backwards** (2026-08-19). The
  backfill chain deliberately contains versions *older* than the pointer, and
  both the scan report and `--apply` took `chain[-1]` — the newest *missing*
  version — as the new `latest`. For any package already sitting on the newest
  release, every missing entry is older, so the bot proposed a downgrade:
  measured `fd 10.4.2 → 10.4.1`, `qemu-riscv 9.2.4-1 → 8.2.6-1`. The pointer
  now only ever moves forward; backfilled entries are still appended.

## Recipes migrated

| Recipe | spec | Change |
|--------|------|--------|
| `node` | 1 → 2 | **Bug fix + arch coverage.** Declared `archs={x86_64}` while shipping a `darwin-arm64`-only macOS URL and x64-only linux/windows. Now `archs={x86_64,aarch64}`; the per-version builder functions return per-arch maps (arm64 linux/windows, x64 macOS); install dir templates are arch-aware. No `url_template` dependency, so this migrates cleanly. |

## Follow-up (needs maintainer reconciliation)

- `github-gh`: has the same amd64-for-every-arch bug, but upstream maintains it
  via a `url_template` field consumed by the version-check bot. Migrating to
  per-arch maps must be reconciled with that templating/auto-versioning
  mechanism (e.g. an arch-aware `url_template`) rather than removed — left to
  a follow-up so the bot keeps working.
- `cmake`: already arch-correct via `XLINGS_RES` (which embeds the host arch).
  Migrating to the `res` shape would add per-arch checksums — deferred until
  real per-arch sha256 values are available from the resource server.
