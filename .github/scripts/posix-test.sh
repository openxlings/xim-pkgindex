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

# Register official sub-indexes so packages that delegate to them resolve.
# e.g. xim:linux-headers is a thin delegator whose payload lives in
# scode:linux-headers (xim-pkgindex-scode); without the scode index any
# package depending on linux-headers (llvm, gcc, glibc, ...) fails to install
# with "package 'scode:linux-headers@<ver>' not found". Best-effort.
"$XLINGS_CMD" config --index-repo "scode:https://github.com/openxlings/xim-pkgindex-scode.git" 2>/dev/null || true

# Put this repo's libs/ where a locally-registered recipe can import it.
#
# `config --add-xpkg` copies the recipe into the LOCAL index, and
# `import("xim.pkgindex.sysroot")` resolves against the index the recipe came
# from. The local index has no libs/, so the import falls through to the
# unknown-module stub — whose every field is a truthy callable that returns
# another stub. So every sysroot call in a recipe under test succeeded and did
# nothing, and the branch guarded by `if not sysroot.declare_headers_tree(...)`
# never took its fallback either.
#
# This is why a change that replaced the whole subos sysroot with a symlink
# into one package's payload passed install-test green: the code that would
# have done it was inert here, and only ran once published. A test that cannot
# execute the thing it is testing reports on nothing.
if [[ -d "$WORKSPACE_ROOT/libs" ]]; then
    mkdir -p "$XLINGS_HOME_DIR/data/xim-pkgindex-local/libs"
    cp "$WORKSPACE_ROOT/libs/"*.lua \
       "$XLINGS_HOME_DIR/data/xim-pkgindex-local/libs/" 2>/dev/null || true
fi

# Register every changed descriptor BEFORE testing any of them.
#
# The loop below registers each package immediately before installing it, which
# is enough while a PR adds packages that only depend on already-published ones.
# It cannot handle a PR that adds a stack: the graphics packages depend on each
# other, so installing libX11 needs libxcb, which this PR also adds and which
# has not been registered yet when libX11's turn comes. The failure reads as
# "package 'libxcb@>=1.17' not found" for a recipe sitting in the same diff.
#
# Same reasoning as the scode line above — make the things a dependency can
# point at resolvable first, then test. Registration is idempotent, so the
# loop's own add-xpkg stays as it is.
# A recipe under test SHADOWS its published copy; it does not coexist with it.
#
# `config --add-xpkg` registers the changed recipe under `local:`, while the
# published one stays in the `xim:` index. Two candidates for one package is a
# state that never exists after merge, and it breaks the run in two ways that
# both look like bugs in the diff:
#
#   1. AMBIGUITY. Any recipe -- including a PUBLISHED one this PR cannot edit --
#      that names a dep WITHOUT a namespace now has two candidates and fails
#      with "package 'expat@2.6.2' is ambiguous". Published `xim:fontconfig`
#      says `expat@2.6.2`, so merely touching expat broke fontconfig AND
#      graphics. Whether a PR passes then depends on which OTHER packages it
#      happens to touch.
#
#   2. DOUBLE INSTALL FROM ONE EXTRACTION. `xim:libffi` gets pulled in as some
#      other package's dependency and its install hook MOVES the extracted
#      source tree into place. When `local:libffi` is then installed for its own
#      test, there is no download artifact and therefore no extraction, the
#      recipe's `os.mv` finds nothing, `install()` returns true anyway, and
#      xlings prints a tick over an EMPTY payload directory. The only complaint
#      came from the config hook two steps later, about pkgconfig globs.
#
# So the recipe under test is written OVER the published one, in place, in the
# same namespace. One candidate, and it is the PR's -- exactly the state the
# merge produces.
#
# Deleting the published copy instead is not equivalent and was tried: it also
# leaves one candidate, but it removes the `xim:` NAME, so every dep that
# qualifies itself -- `xim:expat@2.6.2`, `xim:libffi@>=3.4` -- stops resolving.
# Overlay keeps the name and changes only the content.
#
# Guarded to a real directory: when the index path is a symlink (a developer
# pointing their home at this very checkout) the copy would write back into the
# source tree. In that case, and if the overlay fails for any other reason, the
# caller falls back to the old `--add-xpkg` behaviour rather than skipping the
# package.
# Only for a recipe that ALREADY EXISTS upstream — i.e. a change to a published
# package. That is precisely the case that produces the duplicate, and it is the
# only case overlay can serve.
#
# A package the PR ADDS is not in the index, so asking for it by its index name
# makes xlings say `'xim:<pkg>' not in current index; refreshing index...` and
# re-fetch the whole index — which overwrites the file that was just placed
# there, and the install then fails with `not found`. New packages therefore
# keep the `--add-xpkg` / `local:` path, where they are unambiguous anyway:
# nothing published shares the name, so there is no second candidate.
#
# This also matches the namespace rule the index already follows — a new package
# is referenced bare, a changed published one with `xim:`.
INDEX_DIR="$XLINGS_HOME_DIR/data/xim-pkgindex"
overlay_recipe() {
    local rel_file="$1"
    [[ -d "$INDEX_DIR" && ! -L "$INDEX_DIR" ]] || return 1
    [[ -f "$INDEX_DIR/$rel_file" ]] || return 1   # not published: not ours to overlay
    cp -f "$WORKSPACE_ROOT/$rel_file" "$INDEX_DIR/$rel_file" || return 1
    return 0
}

# The same reasoning applies to libs/: a recipe overlaid into the xim index
# imports `xim.pkgindex.*` from THAT index, so the PR's helpers have to be there
# too. Without this the imports fall through to the permissive stub and every
# helper call is a truthy no-op -- the failure mode already described above for
# the local index.
if [[ -d "$WORKSPACE_ROOT/libs" && -d "$INDEX_DIR" && ! -L "$INDEX_DIR" ]]; then
    mkdir -p "$INDEX_DIR/libs"
    cp "$WORKSPACE_ROOT/libs/"*.lua "$INDEX_DIR/libs/" 2>/dev/null || true
fi

for rel_file in "${files[@]}"; do
    [[ -n "$rel_file" ]] || continue
    [[ -f "$WORKSPACE_ROOT/$rel_file" ]] || continue
    if ! overlay_recipe "$rel_file"; then
        "$XLINGS_CMD" config --add-xpkg "$WORKSPACE_ROOT/$rel_file" >/dev/null 2>&1 || true
    fi
done

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
    # Overlay wins; `--add-xpkg` is the fallback for a home whose index copy is
    # not writable. `pkg_ns` is corrected below to match whichever ran.
    if overlay_recipe "$rel_file"; then
        [[ "$pkg_ns" == "local" ]] && pkg_ns="xim"
        info "overlaid into the index as ${pkg_ns}:${pkg}"
    elif ! "$XLINGS_CMD" config --add-xpkg "$lua_file"; then
        log_fail "config --add-xpkg failed"; failures+=("$rel_file (register)"); continue
    fi

    # `namespace = "config"` is not a package — it's a bundle of system-side
    # configuration steps (hosts files, fontconfig, PowerShell policy,
    # .vscode/settings.json, mirror endpoints, etc.). The install/uninstall
    # lifecycle assertion is not the right shape for it, and it also collides
    # with the xim global repo on `config:<name>@<ver>` after merge (both repos
    # carry the same spec, no way to disambiguate by repo). Register-only is
    # enough; the static/isolation/index suites still validate the xpkg shape.
    # Other namespaces remain full lifecycle tests.
    if [[ "$pkg_ns" == "config" ]]; then
        info "skip (install/uninstall not asserted for namespace='config')"
        continue
    fi

    shims_before=$(shim_set)
    info "shims before install: $(printf '%s\n' "$shims_before" | grep -c . || true)"

    pkg_spec="${pkg_ns}:${pkg}"

    step "[$pkg] install ($pkg_spec)"
    if ! "$XLINGS_CMD" install "$pkg_spec" -y; then
        log_fail "install failed"; failures+=("$rel_file (install)"); continue
    fi

    step "[$pkg] post-install checks"
    install_dirs=$(pkg_install_dirs "$pkg")
    installed_version=""
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
                [[ -n "$installed_version" ]] || installed_version=$(basename "$(printf '%s\n' "$versions" | head -1)")
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

    # A payload's loader and its libc must come from the same payload.
    #
    # `ld.so` and `libc.so.6` are two halves of one build, talking over
    # GLIBC_PRIVATE symbols that promise nothing across versions. A package
    # that got them from different payloads installs cleanly, passes every
    # check above, and faults before `main` on the user's machine with a
    # message naming neither package nor version.
    #
    # xlings 2026.8.5.3 refuses to finish such an install, so this should
    # never fire. It is here because the check that never fires is exactly
    # the one worth keeping: it costs one string compare per binary, and it
    # is what turns "we believe that cannot happen" into something CI states.
    if [[ "$HOST_OS" == "linux" ]] && command -v patchelf >/dev/null 2>&1; then
        step "[$pkg] loader/libc same-source"
        split_found=0
        while IFS= read -r -d '' elf; do
            [[ "$(head -c4 "$elf" 2>/dev/null)" == $'\x7fELF' ]] || continue
            interp="$(patchelf --print-interpreter "$elf" 2>/dev/null)" || continue
            [[ -n "$interp" ]] || continue
            payload_of() { sed -E 's#(.*/xpkgs/[^/]+/[^/]+)/.*#\1#' <<<"$1"; }
            iroot="$(payload_of "$interp")"
            [[ "$iroot" == *"/xpkgs/"* ]] || continue
            provider="$(sed -E 's#.*/xpkgs/([^/]+)/[^/]+$#\1#' <<<"$iroot")"
            rp="$(patchelf --print-rpath "$elf" 2>/dev/null)"
            same=0; other=""
            IFS=: read -ra parts <<<"$rp"
            for part in "${parts[@]}"; do
                case "$part" in *"/xpkgs/$provider/"*)
                    r="$(payload_of "$part")"
                    [[ "$r" == "$iroot" ]] && same=1 || other="$r" ;;
                esac
            done
            if [[ -n "$other" && $same -eq 0 ]]; then
                log_fail "loader/libc split: ${elf##*/} interp=$iroot rpath=$other"
                split_found=1
            fi
        done < <(find "$XPKGS_DIR" -type f ! -type l -print0 2>/dev/null)
        if [[ $split_found -eq 1 ]]; then
            failures+=("$rel_file (loader/libc split)"); continue
        fi
        log_pass "loader and libc come from one payload"
    fi

    # Declared deps vs the payload's real DT_NEEDED.
    #
    # Runs here, on the freshly installed payload, because that is the only
    # place both halves exist at once: the recipe's declaration and the bytes
    # xlings produced from it. A static check of the recipe cannot see what the
    # binaries need, and a check of the binaries alone cannot see what was
    # promised.
    #
    # Exit 3 is "this machine could not evaluate it" (no readelf, no lua, a
    # payload with no ELF in it) and must not be read as a pass -- so it is
    # reported and skipped, not folded into log_pass. See .agents/tools/README.md.
    if [[ "$HOST_OS" == "linux" && -n "$installed_version" ]]; then
        step "[$pkg] declared deps vs DT_NEEDED"
        # `examined` exists because the first version of this block could print
        # its header and then nothing at all. A script-type package has no
        # payload directory, so `install_dirs` is empty, `<<<` still feeds the
        # loop one empty line, the -d test skips it, and the step reported
        # neither pass nor skip -- a check announcing itself and going silent,
        # which is the exact shape the check was added to remove.
        examined=0
        while IFS= read -r dir; do
            [[ -n "$dir" && -d "$dir/$installed_version" ]] || continue
            examined=$((examined + 1))
            "$WORKSPACE_ROOT/.github/scripts/dep-closure-check.sh" \
                "$dir/$installed_version" "$lua_file" "$HOST_OS" "$XPKGS_DIR"
            case $? in
                0) log_pass "dependency closure complete" ;;
                3) info "not evaluated on this machine (exit 3)" ;;
                *) log_fail "dependency closure incomplete"
                   failures+=("$rel_file (dep-closure)") ;;
            esac
        done <<< "$install_dirs"
        [[ $examined -eq 0 ]] \
            && info "no payload directory for '$pkg' (type=$pkg_type); nothing to check"
    fi

    # Remove exactly what this test installed, not "whatever is active" — a
    # bare removal resolves the ACTIVE version, which for a binding-group member
    # can carry a provider annotation that is a DISPLAY form, not a key.
    if [[ -n "$installed_version" ]]; then
        remove_spec="${pkg_spec}@${installed_version}"
    else
        remove_spec="$pkg_spec"
    fi

    step "[$pkg] uninstall ($remove_spec)"
    remove_out="$("$XLINGS_CMD" remove "$remove_spec" -y 2>&1)"; remove_rc=$?
    printf '%s\n' "$remove_out"
    if [[ $remove_rc -ne 0 ]]; then
        # A `type = "config"` package configures the system and registers no
        # xvm version of its own, so there is nothing for removal to select:
        #
        #   uninstall failed: xvm removal selection failed for xim:cpp@gnu:
        #   removal version is not registered (target='cpp', version='gnu')
        #
        # 11 of the 12 config-type recipes in this index call xvm.add zero
        # times, so this is the shape of the type rather than a fault in one
        # recipe -- the same reason the `namespace = "config"` branch above
        # skips the lifecycle assertion entirely. Whether `remove` should
        # succeed as a no-op there is a real question, and an xlings-side one;
        # it is not this test's to answer, and it is not what put these
        # recipes in the changed set.
        #
        # Narrow on purpose: the config type AND this exact diagnostic. Keying
        # on the type alone would also swallow a genuine removal bug in
        # `xvm-sysdetect`, the one config package that DOES call xvm.add -- and
        # a tolerance that hides the case it was not written for is how a
        # skipped assertion becomes permanent.
        if [[ "$pkg_type" == "config" ]] \
           && grep -q "removal version is not registered" <<<"$remove_out"; then
            info "uninstall not asserted: type='config' registers no xvm version"
            info "  (${remove_spec} -- see the note in this script)"
            continue
        fi
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
