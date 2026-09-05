#!/usr/bin/env bash
# Build a versioned xim package-index *artifact* + manifest for publishing
# to xlings-res (Y-asset model; see .agents/docs/2026-06-22-index-as-resource-impl-plan.md).
#
# An index artifact is a plain tarball of the index tree (pkgs/, .xpkgindex.json,
# xim-indexrepos.lua, ...) with the .git history stripped, plus a manifest.json
# describing it (sha256/size + format_version + a reserved signature slot for a
# future minisign/X-full upgrade).
#
# Output (in OUT_DIR):
#   xim-index[-<name>]-<ver>.tar.gz
#   xim-index[-<name>]-<ver>.manifest.json
#
# Usage:
#   tools/build_xim_index_artifact.sh --version <ver> --out <dir> [--name <sub>] [--src <dir>]
#
# Env:
#   XLINGS_RELEASE_MIRROR=GLOBAL|CN     pick clone origin when --src omitted (default GLOBAL)
#   XLINGS_RELEASE_PKGINDEX_URL         override clone URL
#   XLINGS_RELEASE_PKGINDEX_REF=main    git ref to snapshot (default main)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="" OUT_DIR="" NAME="" SRC_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --out)     OUT_DIR="$2"; shift 2 ;;
    --name)    NAME="$2";    shift 2 ;;
    --src)     SRC_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$VERSION" || -z "$OUT_DIR" ]] && { echo "usage: $0 --version <ver> --out <dir> [--name <sub>] [--src <dir>]" >&2; exit 2; }

info() { echo "[index-artifact] $*"; }
fail() { echo "[index-artifact] FAIL: $*" >&2; exit 1; }

# sha256 helper (Linux: sha256sum, macOS: shasum -a 256)
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else fail "no sha256 tool (sha256sum/shasum)"; fi
}

MIRROR="${XLINGS_RELEASE_MIRROR:-GLOBAL}"
REF="${XLINGS_RELEASE_PKGINDEX_REF:-main}"
# Sub-index name → repo. Main index has no name.
if [[ -z "$NAME" ]]; then
  case "$MIRROR" in
    CN) DEFAULT_URL="https://gitee.com/sunrisepeak/xim-pkgindex.git" ;;
    *)  DEFAULT_URL="https://github.com/openxlings/xim-pkgindex.git" ;;
  esac
  ARTIFACT_BASE="xim-index-${VERSION}"
else
  DEFAULT_URL="https://github.com/d2learn/xim-pkgindex-${NAME}.git"
  ARTIFACT_BASE="xim-index-${NAME}-${VERSION}"
fi
URL="${XLINGS_RELEASE_PKGINDEX_URL:-$DEFAULT_URL}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/xim-index-build.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

TREE="$TMP_ROOT/tree"
if [[ -n "$SRC_DIR" ]]; then
  info "Using local source: $SRC_DIR"
  [[ -d "$SRC_DIR/pkgs" ]] || fail "source dir missing pkgs/: $SRC_DIR"
  cp -a "$SRC_DIR" "$TREE"
else
  info "Cloning $URL ($REF)"
  if ! git clone --depth 1 --branch "$REF" "$URL" "$TREE" 2>/dev/null; then
    rm -rf "$TREE"
    git clone "$URL" "$TREE"
    git -C "$TREE" checkout --quiet "$REF"
  fi
fi

# Record source commit (before stripping .git) for traceability.
SOURCE_COMMIT="unknown"
if [[ -d "$TREE/.git" ]]; then
  SOURCE_COMMIT="$(git -C "$TREE" rev-parse HEAD 2>/dev/null || echo unknown)"
fi
rm -rf "$TREE/.git"
[[ -d "$TREE/pkgs" ]] || fail "index tree missing pkgs/ after fetch"

ARTIFACT="$OUT_DIR/${ARTIFACT_BASE}.tar.gz"

# THE BYTES FOR AN INDEX COMMIT ARE DECIDED ONCE.
#
# The artifact name carries the index commit, so a rerun on an unchanged HEAD --
# which is exactly what the nightly cron in publish-artifact.yml does -- rebuilds
# an artifact that already exists, under the same name, and publish uploads it
# with --clobber. The pack below was never byte-reproducible (file mtimes come
# from the checkout, and gzip stamps its own header), so the rerun replaced a
# published artifact with different bytes while the pointer moved to the new
# sha256. Every client that had already read the old pointer then downloaded
# bytes its manifest did not describe:
#
#   [warn] [index] 'xim' artifact fetch failed (sha256 mismatch
#     (source .../xim-index-1f4b39d.tar.gz): got ce2e9c7f..., want 1c9ba720...)
#
# and fell back to whatever local copy it had -- reporting `not found` for a
# package the index carries. Measured 2026-09-05: v1f4b39d was published at
# 18:14 as 967096 bytes (1c9ba720...) and replaced at 19:37, same commit, with
# 967087 bytes (ce2e9c7f...); mcpp CI went red on `mcpp@2026.9.5.4 not found`.
#
# So: if this version is already published, that copy IS the artifact. The cron
# keeps its catch-up purpose -- it can still reach a mirror that missed the
# upload, or refresh the pointer -- but it can no longer change what a version
# means. XLINGS_INDEX_NO_REUSE=1 forces a rebuild.
REUSE_BASE="${XLINGS_INDEX_REUSE_BASE:-https://github.com/xlings-res/xim-index/releases/download}"
reused=0
if [[ "${XLINGS_INDEX_NO_REUSE:-0}" != 1 ]]; then
  reuse_url="${REUSE_BASE}/v${VERSION}/${ARTIFACT_BASE}.tar.gz"
  if curl -fsSL --retry 3 --retry-all-errors -o "${ARTIFACT}.reuse" "$reuse_url" 2>/dev/null \
     && [[ -s "${ARTIFACT}.reuse" ]]; then
    mv -f "${ARTIFACT}.reuse" "$ARTIFACT"
    reused=1
    info "Reusing the artifact already published for $VERSION"
    info "  $reuse_url"
  else
    rm -f "${ARTIFACT}.reuse"
  fi
fi

if [[ "$reused" == 0 ]]; then
  # Reproducible tarball: sorted names, stable owners, fixed mtimes, and a gzip
  # header with no timestamp (-n). Without the last two, two packs of the same
  # tree differ, which is the defect described above.
  info "Packing $ARTIFACT"
  tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
      --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
      -cf - -C "$TREE" . 2>/dev/null | gzip -n -9 > "$ARTIFACT" \
    || tar -czf "$ARTIFACT" -C "$TREE" .   # BSD tar fallback (not reproducible)
fi

SHA="$(sha256_of "$ARTIFACT")"
SIZE="$(wc -c < "$ARTIFACT" | tr -d ' ')"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# #476: the index tree may declare which client versions it needs, in
# `index-compat.json` at its root:
#
#   { "requires": { "xlings": { "min": "2026.8.4.1" } } }
#
# Carried into the manifest verbatim. xlings evaluates only the "xlings" key
# and routes clients that do not satisfy it to an older snapshot; every other
# key is passed through for whichever consumer owns it. Absent file = no
# constraint = today's behaviour.
REQUIRES_JSON="{}"
# From the assembled TREE, not --src: the clone path has no SRC_DIR, and the
# tree is what actually ships.
COMPAT_FILE="$TREE/index-compat.json"
if [[ -f "$COMPAT_FILE" ]]; then
  REQUIRES_JSON="$(python3 "$SCRIPT_DIR/read_index_compat.py" "$COMPAT_FILE")" \
    || fail "index-compat.json rejected"
  info "  requires: $REQUIRES_JSON"
fi

MANIFEST="$OUT_DIR/${ARTIFACT_BASE}.manifest.json"
cat > "$MANIFEST" <<JSON
{
  "format_version": 1,
  "index_version": "${VERSION}",
  "index_name": "${NAME:-xim}",
  "generated_at": "${GENERATED_AT}",
  "source_commit": "${SOURCE_COMMIT}",
  "artifact": {
    "name": "${ARTIFACT_BASE}.tar.gz",
    "sha256": "${SHA}",
    "size": ${SIZE}
  },
  "requires": ${REQUIRES_JSON},
  "signature": null
}
JSON

info "Done:"
info "  artifact: $ARTIFACT"
info "  sha256:   $SHA  ($SIZE bytes)"
info "  manifest: $MANIFEST"
