#!/usr/bin/env bash
# Publish the graphics-stack payloads to xlings-res, both regions.
#
# Chain per mcpp's docs/10-publishing-a-library.md, applied to xim-pkgindex:
#
#   tarball → github.com/xlings-res/<name> release  (GLOBAL)
#           → gitcode.com/xlings-res/<name>         (CN, byte-identical)
#           → recipe in this repo pointing at both, with the sha256
#
# Verification is not optional and not a HEAD request. GitCode answers HEAD
# with 401 and GET with a redirect to its CDN, so an asset checked with HEAD
# reads as broken while an asset checked only for existence can still be the
# wrong bytes. Both regions are downloaded and compared against the local file.
#
# Usage:  publish.sh <distdir> [name-version ...]      (default: everything)
set -uo pipefail

DIST="${1:?usage: publish.sh <distdir> [pkg ...]}"; shift || true
ORG=xlings-res
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log()  { echo "[publish] $*"; }
warn() { echo "[publish] WARN: $*" >&2; }
fail() { echo "[publish] FAIL: $*" >&2; exit 1; }

command -v gh  >/dev/null || fail "gh not found"
command -v gtc >/dev/null || warn "gtc not found — CN mirror will be skipped"

shopt -s nullglob
FILES=("$DIST"/*.tar.gz)
[[ ${#FILES[@]} -gt 0 ]] || fail "no tarballs in $DIST"

README_DIR="${XLINGS_GFX_README_DIR:-/tmp/xlings-res-readme}"

MANIFEST="$DIST/RECIPE-DATA.txt"
: > "$MANIFEST"

for f in "${FILES[@]}"; do
    base="$(basename "$f")"                       # name-version-linux-x86_64.tar.gz
    stem="${base%-linux-x86_64.tar.gz}"
    name="${stem%-*}"
    version="${stem##*-}"
    [[ -n "$name" && -n "$version" ]] || { warn "cannot parse $base"; continue; }

    if [[ $# -gt 0 ]] && ! printf '%s\n' "$@" | grep -qx "$stem"; then continue; fi

    sha="$(sha256sum "$f" | cut -d' ' -f1)"
    log "$name $version  ($(du -h "$f" | cut -f1))"

    gh repo view "$ORG/$name" >/dev/null 2>&1 || {
        gh repo create "$ORG/$name" --public \
           --description "xlings-res payload: $name" >/dev/null 2>&1 \
          || warn "could not create $ORG/$name (may already exist)"
    }

    # The README is the repo's first commit, and that is load-bearing rather
    # than tidy: GitHub refuses to create a release on an empty repository
    # ("HTTP 422: Repository is empty"), so a freshly created payload repo
    # cannot receive its asset until something is committed. It also carries
    # the build details — a payload repo holds only tarballs, so how those
    # bytes were produced exists nowhere else.
    if [[ -f "$README_DIR/$name/README.md" ]]; then
        b64="$(base64 -w0 "$README_DIR/$name/README.md")"
        cur_sha="$(gh api "repos/$ORG/$name/contents/README.md" -q .sha 2>/dev/null || true)"
        if [[ -n "$cur_sha" ]]; then
            gh api "repos/$ORG/$name/contents/README.md" -X PUT \
               -f message="docs: how this payload is built" \
               -f content="$b64" -f sha="$cur_sha" >/dev/null 2>&1 \
              || warn "$name: README update failed"
        else
            gh api "repos/$ORG/$name/contents/README.md" -X PUT \
               -f message="docs: how this payload is built" \
               -f content="$b64" >/dev/null 2>&1 \
              || warn "$name: README create failed"
        fi
    fi

    # Errors are shown, not swallowed. The first version of this script sent
    # every gh invocation to /dev/null, so all twenty-two packages failed
    # identically and silently on "Repository is empty" — a diagnosis the
    # output could not support.
    if ! gh release view "$version" --repo "$ORG/$name" >/dev/null 2>&1; then
        gh release create "$version" --repo "$ORG/$name" \
             --title "$version" --notes "Built from source against the xlings subos glibc." \
          || { warn "$name: cannot create release $version"; continue; }
    fi
    gh release upload "$version" "$f" --repo "$ORG/$name" --clobber \
      || { warn "$name: GitHub upload failed"; continue; }

    GLOBAL="https://github.com/$ORG/$name/releases/download/$version/$base"
    CN="https://gitcode.com/$ORG/$name/releases/download/$version/$base"

    if command -v gtc >/dev/null; then
        # The CN repo has to exist first — gtc reports a missing one as
        # `404 project not found` from the releases endpoint, which reads like
        # a release problem rather than a repository problem. Creating is
        # idempotent enough: an existing repo just errors and is ignored.
        gtc repo create "$ORG/$name" --description "xlings-res payload: $name" \
            >/dev/null 2>&1 || true
        # And the same first-commit requirement as GitHub, reported differently:
        # gitcode answers `400 main is not exist` from the releases endpoint,
        # which reads like a release problem rather than an empty repository.
        if [[ -d "$README_DIR/$name" ]]; then
            gtc repo push "$ORG/$name" "$README_DIR/$name" \
                -m "docs: how this payload is built" >/dev/null 2>&1 || true
        fi
        gtc release publish "$ORG/$name" --tag "$version" --asset "$f" >/dev/null 2>&1 \
          || warn "$name: gtc publish reported a problem"
    fi

    # Verify by downloading, from both regions, and comparing bytes. A mirror
    # that 200s with different content is the failure this catches; a digest
    # in the recipe would then be right for one region and wrong for the other.
    ok_global=no ok_cn=no
    if curl -fsSL --retry 2 --max-time 300 -o "$TMP/g.bin" "$GLOBAL" 2>/dev/null \
       && cmp -s "$TMP/g.bin" "$f"; then ok_global=yes; fi
    if curl -fsSL --retry 2 --max-time 300 -o "$TMP/c.bin" "$CN" 2>/dev/null \
       && cmp -s "$TMP/c.bin" "$f"; then ok_cn=yes; fi

    log "  GLOBAL=$ok_global  CN=$ok_cn  sha256=${sha:0:16}…"
    [[ "$ok_global" == yes ]] || warn "$name: GLOBAL asset does not match the local file"

    printf '%s|%s|%s|%s|%s|%s\n' "$name" "$version" "$sha" "$GLOBAL" "$CN" "$ok_cn" >> "$MANIFEST"
done

log "recipe data → $MANIFEST"
