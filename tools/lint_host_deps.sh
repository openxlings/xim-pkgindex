#!/usr/bin/env bash
# Lint: what this index's CI takes from a runner is the T0 list (xlings: the
# aarch64 design §2.1, HOST-DEPS-T0) -- a machine's package manager installing
# something is a failure unless the line says why it must be the machine's
# with `host-dep-ok: <why>` (a pinned build container's recipe, a bare
# distribution being prepared to install xlings). Workflows not yet audited
# are listed in tools/host-deps-pending.txt, each with its reason; the list
# only shrinks.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern='(apt-get|apt|dnf|yum|zypper|pacman|apk|brew|choco|winget|scoop)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(install|add|-S[a-zA-Z]*|-U)\b|pip3?[[:space:]]+install'
pending="$(grep -v '^#' tools/host-deps-pending.txt | awk '{print $1}' || true)"
files="$(git ls-files .github/workflows scripts tools tests/scripts | grep -E '\.(ya?ml|sh|py)$' || true)"
hits=""
for f in $files; do
    grep -qxF "$f" <<<"$pending" && continue
    [[ "$f" == tools/lint_host_deps.sh || "$f" == tools/res/build.sh ]] && continue   # the factory's containers
    h="$(grep -nE "$pattern" "$f" | grep -v 'host-dep-ok' | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
    [[ -n "$h" ]] && hits+="$(sed "s|^|$f:|" <<<"$h")"$'\n'
done
if [[ -n "${hits//$'\n'/}" ]]; then
    while IFS= read -r h; do [[ -n "$h" ]] && echo "::error::a machine's package manager installs here: $h"; done <<<"$hits"
    echo "install it through xlings, or say why it must be the machine's: host-dep-ok: <why>" >&2
    exit 1
fi
echo "host deps: only the T0 list (pending audit: $(grep -cv '^#' tools/host-deps-pending.txt) workflows)"
