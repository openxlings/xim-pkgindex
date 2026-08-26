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

# Post-uninstall shim-leak check, shared by the in-loop path and the
# deferred fixed-point path below. Only shims OWNED by the package (named in
# its `programs` list) count as a leak: shims that arrived with the deps are
# the deps' own lifecycle and remain installed by design.
check_shim_leak() {
    local rel_file="$1" new_shims="$2" programs="$3"
    local shims_final survived leftover shim prog
    shims_final=$(shim_set)
    survived=$(comm -12 <(printf '%s\n' "$new_shims") <(printf '%s\n' "$shims_final"))
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

# Bound a command's wall clock, on both Linux and macOS.
#
# `timeout` is GNU coreutils and is NOT on a stock macOS runner -- adding it
# unconditionally turned every macos-install-test install into
# `timeout: command not found` inside 19 seconds. Homebrew's coreutils installs
# it as `gtimeout`, which may or may not be there.
#
# So: use whichever exists, and when neither does, do it in shell rather than
# silently dropping the bound -- an unbounded run is the failure mode this was
# added to prevent, and "no timeout available" must not read as "no timeout
# needed". Returns 124 on expiry, matching timeout(1).
TIMEOUT_BIN="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"

run_bounded() {
    local secs="$1"; shift
    if [[ -n "$TIMEOUT_BIN" ]]; then
        "$TIMEOUT_BIN" "$secs" "$@"
        return $?
    fi
    "$@" &
    local pid=$! waited=0
    while kill -0 "$pid" 2>/dev/null; do
        if [[ $waited -ge $secs ]]; then
            kill -TERM "$pid" 2>/dev/null
            sleep 2
            kill -KILL "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            return 124
        fi
        sleep 2
        waited=$((waited + 2))
    done
    wait "$pid"
    return $?
}

read -r -a files <<< "$CHANGED_FILES"
if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No changed .lua files. Nothing to test."
    exit 0
fi

failures=()
tested=0
skipped=0

# Deferred uninstalls, retried to a fixed point after the main loop.
#
# The per-package flow removes only the package under test; its DEPS stay
# installed for the rest of the run. So when the changed set contains both a
# library and its consumer (glibc + ncurses, glibc + jdk), the library's turn
# can come first and its removal is refused by the reverse-dependency guard —
# the guard being RIGHT and the fixed order being naive. Those removals are
# deferred and retried in rounds once every changed package has had its own
# uninstall; see the fixed-point block after the loop.
deferred_files=()
deferred_pkgs=()
deferred_specs=()
deferred_shims=()
deferred_programs=()
deferred_errs=()
# Bare names of every changed package this run actually install-tested —
# the discriminator for the fixed point's terminal state. `uninstalled_pkgs`
# holds the ones whose own uninstall assertion already PASSED: a later
# package may re-install one of those as its dependency (xmake pulls ncurses
# back in after ncurses' own turn), and a resident re-install blocking the
# fixed point is the harness's leave-deps-installed design, not an ordering
# bug — its uninstall was already proven.
changed_pkgs=()
uninstalled_pkgs=()

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
# A package the PR ADDS is not in the index either, and it used to be excluded
# here: asking for a name the index does not carry made xlings say
# `'xim:<pkg>' not in current index; refreshing index...` and re-fetch the whole
# index, overwriting the file just placed there. So new packages took the
# `--add-xpkg` / `local:` path instead.
#
# That exclusion has a cost the ecosystem hit as soon as a PR added a package
# AND a consumer of it in one change: #680 adds util-linux and libselinux and
# makes glib depend on `xim:util-linux@>=2.40`. Both new recipes registered
# fine — as `local:` — and glib then failed with `package 'xim:util-linux@>=2.40'
# not found`, which is not a defect in any of the three recipes. Under the old
# rule that PR is untestable in principle: it can only go green after a merge
# that CI was supposed to gate.
#
# What makes the new package overlayable is dropping the index's entry cache
# with it. The refresh the comment above describes is triggered by the name
# missing from that cache, not by the file missing from the tree — so placing
# the .lua and invalidating the cache lets the client rescan the directory and
# find it as `xim:<pkg>`, with no re-fetch to overwrite anything. Verified both
# ways before this was written: with the cache left in place the name does not
# resolve; with it dropped, `xlings search` lists `xim:util-linux` from a plain
# file copy.
#
# The verification below keeps that a claim this script can back: if the name
# still does not resolve after the copy, the function reports failure and the
# caller falls back to `--add-xpkg` exactly as before.
INDEX_DIR="$XLINGS_HOME_DIR/data/xim-pkgindex"
overlay_recipe() {
    local rel_file="$1"
    [[ -d "$INDEX_DIR" && ! -L "$INDEX_DIR" ]] || return 1

    local is_new=0
    [[ -f "$INDEX_DIR/$rel_file" ]] || is_new=1

    mkdir -p "$INDEX_DIR/$(dirname "$rel_file")" || return 1
    cp -f "$WORKSPACE_ROOT/$rel_file" "$INDEX_DIR/$rel_file" || return 1
    [[ "$is_new" -eq 0 ]] && return 0

    # New name: the cache is what the resolver reads, so it has to be rebuilt.
    rm -f "$INDEX_DIR/.xlings-index-cache.json"
    local pkg_name; pkg_name="$(basename "$rel_file" .lua)"
    if "$XLINGS_CMD" search "$pkg_name" 2>/dev/null | grep -q "xim:$pkg_name"; then
        return 0
    fi
    # Could not make it resolve under xim: — leave it to --add-xpkg / local:.
    rm -f "$INDEX_DIR/$rel_file"
    return 1
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
    changed_pkgs+=("$pkg")

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

    # Marker for the loader/libc scan below: everything this install writes is
    # newer than this file, which is how that check stops re-walking the whole
    # store once per package.
    install_marker="$(mktemp)"

    step "[$pkg] install ($pkg_spec)"
    # Bounded, for the same reason the Windows leg is: a hook that blocks --
    # an interactive prompt, a GUI-mode script host, an installer waiting on a
    # dialog -- otherwise holds the runner to GitHub's 6-hour ceiling, and no
    # log is served for an in-progress job, so there is nothing to look at
    # while it happens. 124 is timeout(1)'s own code for "killed on time".
    run_bounded 1200 "$XLINGS_CMD" install "$pkg_spec" -y; rc=$?
    if [[ $rc -eq 124 ]]; then
        log_fail "install TIMED OUT after 1200s (a hook is blocking)"
        failures+=("$rel_file (install-timeout)"); continue
    fi
    if [[ $rc -ne 0 ]]; then
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
            # `od`, not `head -c4` in a command substitution. This walks the
            # WHOLE store, which is full of non-ELF files whose first four
            # bytes contain NUL, and bash strips those with
            #
            #   warning: command substitution: ignored null byte in input
            #
            # once per file -- hundreds of lines of it, burying the actual
            # result. Compare the magic as hex instead.
            [[ "$(od -An -tx1 -N4 "$elf" 2>/dev/null | tr -d ' ')" == "7f454c46" ]] || continue
            interp="$(patchelf --print-interpreter "$elf" 2>/dev/null)" || continue
            [[ -n "$interp" ]] || continue
            payload_of() { sed -E 's#(.*/xpkgs/[^/]+/[^/]+)/.*#\1#' <<<"$1"; }
            iroot="$(payload_of "$interp")"

            # HOST interpreter + one of OUR libcs in RPATH.
            #
            # This used to `continue` here, which skipped every binary still on
            # the host loader -- and that is precisely the combination that
            # segfaults. The host's ld.so resolves libc.so.6 through this
            # RPATH, gets ours, and the process dies before main:
            #
            #   $ java -version
            #   __vdso_gettimeofdaySegmentation fault (core dumped)
            #
            # Shipped and reverted on 2026-08-09 (openxlings/xim-pkgindex#578,
            # reverted by #580): declaring `xim:glibc` as a runtime dep put
            # glibc's lib64 into the JDK's RPATH while PT_INTERP stayed the
            # host's. The install reported success and this very step printed
            # "loader and libc come from one payload".
            #
            # The old check only asked "if you use OUR loader, is the libc from
            # the same payload". The converse -- "if you use the HOST loader,
            # you must not pull in our libc" -- is the half that actually
            # crashes, and it was the one being skipped.
            if [[ "$iroot" != *"/xpkgs/"* ]]; then
                rp_host="$(patchelf --print-rpath "$elf" 2>/dev/null)"
                IFS=: read -ra hparts <<<"$rp_host"
                for hp in "${hparts[@]}"; do
                    case "$hp" in *"/xpkgs/"*)
                        # Only a libc-providing payload matters here; pulling
                        # our libX11 under the host loader is fine and common.
                        if compgen -G "$hp/libc.so.6" >/dev/null 2>&1 \
                           || compgen -G "$hp/ld-linux-*.so.*" >/dev/null 2>&1; then
                            log_fail "host loader + our libc: ${elf##*/} interp=$interp rpath=$hp"
                            split_found=1
                        fi ;;
                    esac
                done
                continue
            fi
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
        # Scoped to what THIS install wrote, not the whole store.
        #
        # It used to walk every file under xpkgs for every package, which is
        # quadratic in a run that installs 25 of them: by the late alphabet the
        # store holds every earlier payload, and the step sat for minutes with
        # its header printed and nothing after it -- indistinguishable from a
        # hang, and reported as one. (It was not: the job passed in 21m48s.)
        #
        # -newer than the pre-install marker covers the package AND the deps
        # pulled in with it, which is exactly the set this install could have
        # broken. A split in an older payload is still caught, on the run where
        # that package is the one under test.
        done < <(find "$XPKGS_DIR" -type f ! -type l -newer "$install_marker" -print0 2>/dev/null)
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
    remove_out="$(run_bounded 1200 "$XLINGS_CMD" remove "$remove_spec" -y 2>&1)"; remove_rc=$?
    if [[ $remove_rc -eq 124 ]]; then
        printf '%s\n' "$remove_out"
        log_fail "uninstall TIMED OUT after 1200s (a hook is blocking)"
        failures+=("$rel_file (uninstall-timeout)"); continue
    fi
    printf '%s\n' "$remove_out"
    if [[ $remove_rc -ne 0 ]]; then
        # The `type = "config"` tolerance that used to live here is GONE.
        #
        # It skipped the uninstall assertion when a config-type package failed
        # with `removal version is not registered` -- a package that registers
        # no xvm version had nothing for removal to select. Its own note said
        # "whether `remove` should succeed as a no-op there is a real question,
        # and an xlings-side one".
        #
        # It has been answered on the xlings side: openxlings/xlings#506 makes
        # removal of a package that registered no version succeed and run the
        # recipe's uninstall() hook. That shipped in 2026.8.8.2, which is the
        # client this CI installs since the pin bump.
        #
        # (openxlings/xlings#511 -- removal reporting success while leaving the
        # payload on disk -- is a DIFFERENT, earlier gate and ships in
        # 2026.8.8.3. It is not what this assertion exercises, and this
        # tolerance never covered it.)
        #
        # Deleting this is the acceptance for that work, and it is the only one
        # available: the changed branch cannot be reached from a local fixture
        # (see #511 for the earlier gate that catches an overlapping
        # population), so a green run here IS the test. If it goes red, the fix
        # does not work -- do not re-add the tolerance.

        # Removing xlings when it is the only installed version is refused by
        # design -- that binary is the one running the command, and there is a
        # separate `xlings self uninstall` built for it.
        #
        # This only started happening to bump PRs after #543. Before it, a
        # changed recipe was registered via `config --add-xpkg` and installed
        # as `local:xlings`, which the running-binary guard does not match;
        # #543 made CI overlay the recipe into the index instead, so it now
        # installs as `xim:xlings` and the guard fires. PR #541 (the previous
        # bump) shows `local:xlings@2026.8.7.1` in its log and passed; #548
        # shows `xim:xlings@2026.8.8.1` and did not. Nothing about xlings or
        # about the recipe changed in between.
        #
        # Every future bump PR touches pkgs/x/xlings.lua, so this would be red
        # on all of them.
        if grep -q "cannot remove the running binary itself" <<<"$remove_out"; then
            info "uninstall not asserted: this IS the running xlings, and it is"
            info "  the only installed version (use \`xlings self uninstall\`)"
            continue
        fi

        # Reverse-dependency refusal: the guard is right and the fixed order
        # is naive — another package installed by THIS run still depends on
        # the one under test (glibc's turn comes before its consumers').
        # Defer, do not fail: retried to a fixed point after the loop, and
        # only the fixed point's terminal state decides pass/fail.
        if grep -q "is required by .* installed package" <<<"$remove_out"; then
            info "uninstall deferred: blocked by installed dependents right now;"
            info "  retried after every changed package has had its own uninstall"
            deferred_files+=("$rel_file")
            deferred_pkgs+=("$pkg")
            deferred_specs+=("$remove_spec")
            deferred_shims+=("$new_shims")
            deferred_programs+=("$programs")
            deferred_errs+=("$remove_out")
            continue
        fi
        log_fail "uninstall failed"; failures+=("$rel_file (uninstall)"); continue
    fi

    step "[$pkg] post-uninstall checks"
    uninstalled_pkgs+=("$pkg")
    check_shim_leak "$rel_file" "$new_shims" "$programs"
done

# ── Deferred uninstalls: dependency-agnostic fixed point ────────────────────
#
# Each round retries every remaining removal; a success unblocks its
# dependents for the NEXT round, so any dependency ordering among the changed
# packages converges without this script knowing the graph. Rounds are capped
# at the set size (a chain of N unblocks at most one per round). Failures are
# accounted ONLY at the terminal state, never mid-round.
#
# Terminal state, measured before designed: the test home keeps every DEP
# payload installed on purpose (only the package under test is removed), so a
# changed library that resident deps require — glibc while expat/zlib sit in
# the store — is structurally unremovable here, however many rounds run. That
# is the reverse-dependency guard working as designed on packages OUTSIDE the
# changed set, not a defect in the recipe under test, so it is reported loudly
# and not failed. A blocker INSIDE the changed set at the terminal state is a
# real failure: the fixed point already removed everything removable, so what
# remains is an ordering bug or a dependency cycle in the diff itself.
if [[ ${#deferred_specs[@]} -gt 0 ]]; then
    step "deferred uninstalls: fixed point over ${#deferred_specs[@]} package(s)"
    max_rounds=${#deferred_specs[@]}
    round=0
    while [[ ${#deferred_specs[@]} -gt 0 && $round -lt $max_rounds ]]; do
        round=$((round + 1))
        progressed=0
        keep_files=(); keep_pkgs=(); keep_specs=()
        keep_shims=(); keep_programs=(); keep_errs=()
        i=0
        while [[ $i -lt ${#deferred_specs[@]} ]]; do
            spec="${deferred_specs[$i]}"
            step "[${deferred_pkgs[$i]}] uninstall retry (round $round: $spec)"
            remove_out="$(run_bounded 1200 "$XLINGS_CMD" remove "$spec" -y 2>&1)"; remove_rc=$?
            if [[ $remove_rc -eq 0 ]]; then
                printf '%s\n' "$remove_out"
                progressed=1
                uninstalled_pkgs+=("${deferred_pkgs[$i]}")
                check_shim_leak "${deferred_files[$i]}" "${deferred_shims[$i]}" "${deferred_programs[$i]}"
            else
                info "still blocked (kept for the next round)"
                keep_files+=("${deferred_files[$i]}")
                keep_pkgs+=("${deferred_pkgs[$i]}")
                keep_specs+=("$spec")
                keep_shims+=("${deferred_shims[$i]}")
                keep_programs+=("${deferred_programs[$i]}")
                keep_errs+=("$remove_out")
            fi
            i=$((i + 1))
        done
        deferred_files=(${keep_files[@]+"${keep_files[@]}"})
        deferred_pkgs=(${keep_pkgs[@]+"${keep_pkgs[@]}"})
        deferred_specs=(${keep_specs[@]+"${keep_specs[@]}"})
        deferred_shims=(${keep_shims[@]+"${keep_shims[@]}"})
        deferred_programs=(${keep_programs[@]+"${keep_programs[@]}"})
        deferred_errs=(${keep_errs[@]+"${keep_errs[@]}"})
        [[ $progressed -eq 0 ]] && break
    done

    i=0
    while [[ $i -lt ${#deferred_specs[@]} ]]; do
        spec="${deferred_specs[$i]}"
        remove_out="${deferred_errs[$i]}"
        step "[${deferred_pkgs[$i]}] uninstall blocked at the fixed point ($spec)"
        printf '%s\n' "$remove_out"
        if grep -q "is required by .* installed package" <<<"$remove_out"; then
            # Dependents named in the refusal, reduced to bare names.
            blockers="$(printf '%s\n' "$remove_out" \
                | sed -n 's/^[[:space:]]\{1,\}\([^@ ]\{1,\}\)@.*/\1/p' \
                | sed 's/.*://' | sort -u)"
            blocked_by_changed=""
            for b in $blockers; do
                b_is_changed=0
                for c in ${changed_pkgs[@]+"${changed_pkgs[@]}"}; do
                    [[ "$b" == "$c" ]] && b_is_changed=1
                done
                # A changed blocker whose OWN uninstall already passed is a
                # resident re-install (a later package's dependency), not an
                # ordering bug — see the note at uninstalled_pkgs.
                for u in ${uninstalled_pkgs[@]+"${uninstalled_pkgs[@]}"}; do
                    [[ "$b" == "$u" ]] && b_is_changed=0
                done
                if [[ $b_is_changed -eq 1 ]]; then
                    blocked_by_changed="${blocked_by_changed}${blocked_by_changed:+ }$b"
                fi
            done
            if [[ -n "$blocked_by_changed" ]]; then
                log_fail "still required by changed package(s) after the fixed point: $blocked_by_changed"
                failures+=("${deferred_files[$i]} (uninstall-blocked)")
            else
                info "uninstall not asserted: still required by installed package(s)"
                info "  this run rightly leaves in place ($(printf '%s' "$blockers" | tr '\n' ' '))"
                info "  — each is either outside the change set, or already had its own"
                info "  uninstall asserted and was re-installed as a later package's"
                info "  dependency. That is the reverse-dependency guard working as"
                info "  designed: deps pulled in for a package's test are never removed"
                info "  by this harness, so a changed package they depend on cannot be"
                info "  removed here. Its uninstall hook is exercised on runs where it"
                info "  is not a resident dependency's target."
            fi
        else
            log_fail "uninstall failed"
            failures+=("${deferred_files[$i]} (uninstall)")
        fi
        i=$((i + 1))
    done
fi

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
