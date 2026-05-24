#!/usr/bin/env bash
# Per-package install/uninstall test for POSIX (Linux/macOS), invoked
# from the linux-test / macos-test CI jobs. Bash counterpart of
# windows-test.ps1; same flow, same assertion rules.
#
# Usage:
#   posix-test.sh "<space-separated-changed-files>" <workspace-root> <host-os>
#
# Where <host-os> is "linux" or "macosx", matching the key xpkg uses
# under xpm.

set -u
set -o pipefail

CHANGED_FILES="${1:-}"
WORKSPACE_ROOT="${2:-}"
HOST_OS="${3:-}"

if [[ -z "$WORKSPACE_ROOT" || -z "$HOST_OS" ]]; then
    echo "usage: posix-test.sh <changed-files> <workspace-root> <host-os>" >&2
    exit 2
fi
if [[ "$HOST_OS" != "linux" && "$HOST_OS" != "macosx" ]]; then
    echo "host-os must be 'linux' or 'macosx', got: $HOST_OS" >&2
    exit 2
fi

XLINGS_HOME_DIR="${XLINGS_HOME:-$HOME/.xlings}"
SHIM_DIR="$XLINGS_HOME_DIR/subos/default/bin"
XPKGS_DIR="$XLINGS_HOME_DIR/data/xpkgs"
HAS_KEY="has_$HOST_OS"
XLINGS_CMD="$XLINGS_HOME_DIR/bin/xlings"
if [[ ! -x "$XLINGS_CMD" ]]; then
    XLINGS_CMD="$(command -v xlings 2>/dev/null || true)"
fi
if [[ -z "$XLINGS_CMD" || ! -x "$XLINGS_CMD" ]]; then
    echo "xlings command not found" >&2
    exit 1
fi

cyan() { printf '\033[1;36m%s\033[0m\n' "$*"; }
gray() { printf '\033[0;37m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }

step()    { echo; cyan "==> $*"; }
info()    { gray "  $*"; }
log_pass() { green "  [PASS] $*"; }
log_fail() { red   "  [FAIL] $*"; }

# Snapshot the shim set so we can detect new/disappeared shims around an
# install/uninstall pair. BSD find on macOS does not support -printf, so
# do the listing in pure bash to stay portable.
shim_set() {
    [[ -d "$SHIM_DIR" ]] || return 0
    local entry
    {
        for entry in "$SHIM_DIR"/* "$SHIM_DIR"/.[!.]*; do
            [[ -e "$entry" || -L "$entry" ]] || continue
            basename -- "$entry"
        done
    } | sort
}

# xlings stores installs under <xpkgs>/<ns>-x-<name>/<version>/.
# macOS ships BSD find without GNU's -regextype, so do the regex match
# in bash and stay portable across both systems.
pkg_install_dirs() {
    local pkg="$1"
    [[ -d "$XPKGS_DIR" ]] || return 0
    local d
    for d in "$XPKGS_DIR"/*; do
        [[ -d "$d" ]] || continue
        local name
        name=$(basename "$d")
        if [[ "$name" =~ ^[a-z]+-x-${pkg}$ ]]; then
            printf '%s\n' "$d"
        fi
    done
}

metadata_only_owner_migration() {
    local rel_file="$1"
    local diff changed line content

    diff=$(git -C "$WORKSPACE_ROOT" diff --unified=0 HEAD^ -- "$rel_file" 2>/dev/null || true)
    [[ -n "$diff" ]] || return 1

    changed=$(printf '%s\n' "$diff" | awk '/^[-+]/ && $0 !~ /^(---|\+\+\+)/ { print }')
    [[ -n "$changed" ]] || return 1

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        content="${line:1}"
        [[ "$content" =~ ^[[:space:]]*$ ]] && continue
        if [[ "$content" =~ ^[[:space:]]*(repo|homepage|contributors)[[:space:]]*= ]]; then
            continue
        fi
        return 1
    done <<< "$changed"

    return 0
}

read -r -a files <<< "$CHANGED_FILES"
if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No changed .lua files. Nothing to test."
    exit 0
fi

failures=()
tested=0
skipped=0

for rel_file in "${files[@]}"; do
    [[ -n "$rel_file" ]] || continue
    lua_file="$WORKSPACE_ROOT/$rel_file"
    if [[ ! -f "$lua_file" ]]; then
        info "skip (path does not exist): $rel_file"
        continue
    fi
    if [[ "$lua_file" != *.lua ]]; then
        info "skip (not a .lua file): $rel_file"
        continue
    fi
    if metadata_only_owner_migration "$rel_file"; then
        info "skip (metadata-only owner/link migration): $rel_file"
        skipped=$((skipped+1))
        continue
    fi

    step "Parsing meta: $rel_file"
    if ! meta_json=$(python3 "$WORKSPACE_ROOT/.github/scripts/parse-xpkg-meta.py" "$lua_file"); then
        log_fail "parser failed"
        failures+=("$rel_file (parser)")
        continue
    fi
    pkg=$(printf '%s' "$meta_json"     | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['name'])")
    pkg_type=$(printf '%s' "$meta_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('type','package'))")
    pkg_ns=$(printf '%s' "$meta_json"   | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('namespace','local') or 'local')")
    is_ref=$(printf '%s' "$meta_json"   | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['is_ref'])")
    has_plat=$(printf '%s' "$meta_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('$HAS_KEY', False))")
    programs=$(printf '%s' "$meta_json" | python3 -c "import json,sys; print(' '.join(json.loads(sys.stdin.read())['programs']))")
    info "name=$pkg  type=$pkg_type  namespace=$pkg_ns  programs=[$programs]  is_ref=$is_ref  $HAS_KEY=$has_plat"

    if [[ "$is_ref" == "True" ]]; then
        info "skip (ref package)"; skipped=$((skipped+1)); continue
    fi
    if [[ "$has_plat" != "True" ]]; then
        info "skip (no $HOST_OS branch in xpm)"; skipped=$((skipped+1)); continue
    fi
    if [[ -z "$pkg" ]]; then
        log_fail "package name not parseable"
        failures+=("$rel_file (no-name)"); continue
    fi

    expect_artifacts=false
    case "$pkg_type" in
        package|app|lib) expect_artifacts=true ;;
    esac

    tested=$((tested+1))

    step "[$pkg] register (type=$pkg_type)"
    if ! "$XLINGS_CMD" config --add-xpkg "$lua_file"; then
        log_fail "config --add-xpkg failed"; failures+=("$rel_file (register)"); continue
    fi

    shims_before=$(shim_set)
    info "shims before install: $(printf '%s\n' "$shims_before" | grep -c . || true)"

    # Packages that declare `namespace = "config"` (or any other non-default
    # namespace) are registered under <namespace>:<name> rather than
    # local:<name>, so install/remove must address them by that spec.
    pkg_spec="${pkg_ns}:${pkg}"

    step "[$pkg] install ($pkg_spec)"
    if ! "$XLINGS_CMD" install "$pkg_spec" -y; then
        log_fail "install failed"; failures+=("$rel_file (install)"); continue
    fi

    step "[$pkg] post-install checks"
    install_dirs=$(pkg_install_dirs "$pkg")
    if [[ -z "$install_dirs" ]]; then
        if $expect_artifacts; then
            log_fail "no install dir matching '*-x-$pkg' under $XPKGS_DIR"
            failures+=("$rel_file (install-dir-missing)")
        else
            info "no install dir (expected for type '$pkg_type')"
        fi
    else
        while IFS= read -r dir; do
            versions=$(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
            if [[ -z "$versions" ]]; then
                if $expect_artifacts; then
                    log_fail "install dir has no version subdir: $dir"
                    failures+=("$rel_file (install-dir-empty)")
                else
                    info "install dir present but no version subdir: $dir"
                fi
            else
                while IFS= read -r v; do log_pass "install dir: $v"; done <<< "$versions"
            fi
        done <<< "$install_dirs"
    fi

    shims_after=$(shim_set)
    new_shims=$(comm -13 <(printf '%s\n' "$shims_before") <(printf '%s\n' "$shims_after"))
    if [[ -n "$new_shims" ]]; then
        while IFS= read -r s; do log_pass "new shim: $s"; done <<< "$new_shims"
    fi

    # The presence check is "every declared program has a shim post-install",
    # NOT "every declared program is in the new-shim set". Re-installs and
    # self-installs (e.g. the CI runner already has an xlings shim because
    # it just used xlings to drive the test) leave new_shims empty even
    # though the install did its job — the shim names already existed and
    # were re-pointed at the freshly installed binaries.
    if $expect_artifacts && [[ -n "$programs" ]]; then
        # Use -F (fixed string) + -x (whole line) — program names are literal
        # filenames, not regexes. Plain ERE `^${prog}$` mis-treats characters
        # like `+` (e.g. `musl-c++` parses as `musl-c+` quantifier and never
        # matches the literal `musl-c++` shim).
        for prog in $programs; do
            if ! grep -qFx "$prog" <<< "$shims_after"; then
                log_fail "declared program '$prog' has no shim in $SHIM_DIR"
                failures+=("$rel_file (missing-shim:$prog)")
            fi
        done
    fi
    if [[ -z "$new_shims" ]]; then
        info "no new shim appeared (type='$pkg_type'; programs='$programs' may have been re-pointed)"
    fi

    step "[$pkg] uninstall ($pkg_spec)"
    if ! "$XLINGS_CMD" remove "$pkg_spec" -y; then
        log_fail "uninstall failed"; failures+=("$rel_file (uninstall)"); continue
    fi

    step "[$pkg] post-uninstall checks"
    shims_final=$(shim_set)
    survived=$(comm -12 <(printf '%s\n' "$new_shims") <(printf '%s\n' "$shims_final"))

    # Only flag survivals that are owned by this package — i.e. shims
    # whose name appears in the package's `programs` list. Shims that
    # arrived as a side effect of installing the package's `deps` are
    # the deps' own lifecycle (they remain installed even when this
    # package goes away) and are not a leak.
    leftover=""
    if [[ -n "$survived" && -n "$programs" ]]; then
        for shim in $survived; do
            for prog in $programs; do
                if [[ "$shim" == "$prog" ]]; then
                    leftover="${leftover}${leftover:+ }${shim}"
                    break
                fi
            done
        done
    fi

    if [[ -n "$leftover" ]]; then
        log_fail "shims still present after uninstall: $leftover"
        failures+=("$rel_file (leftover-shim)")
    else
        log_pass "all shims cleaned"
    fi
done

echo
echo "=================================="
cyan " ${HOST_OS} test summary"
echo "=================================="
echo "  tested:   $tested"
echo "  skipped:  $skipped"
echo "  failures: ${#failures[@]}"
if [[ "${#failures[@]}" -gt 0 ]]; then
    for f in "${failures[@]}"; do red "    - $f"; done
    exit 1
fi
exit 0
