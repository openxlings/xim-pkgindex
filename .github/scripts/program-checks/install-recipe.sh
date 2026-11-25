#!/usr/bin/env bash
# install-recipe.sh <recipe> <program> <variable>
#
# Registers the recipe from this checkout, installs it, and publishes the
# installed program's path as <variable> to the following steps. The program
# is addressed by its store path, which is the file the install hook wrote,
# rather than by a shim whose target a later install could change.
set -euo pipefail
recipe="$1"; program="$2"; variable="$3"
name="$(basename "$recipe" .lua)"
xlings="$HOME/.xlings/bin/xlings"

# A client from 2026.10.10.2 does not register a recipe that is byte-identical
# to its published copy -- "nothing to add" -- and `local:` then names nothing.
# Install the namespace the registration produced instead: the `xim:` entry is
# the same bytes this checkout carries (the published index is built from the
# main this branch is based on), and the message stops appearing once a PR
# actually edits the recipe.
register_out="$("$xlings" config --add-xpkg "$recipe" 2>&1)"
printf '%s\n' "$register_out"
ns="local"
if grep -q "is identical to xim:${name};" <<<"$register_out"; then
    ns="xim"
fi

"$xlings" install "${ns}:${name}" -y

found=()
for f in "$HOME/.xlings/data/xpkgs/${ns}-x-$name"/*/bin/"$program"; do
    [ -f "$f" ] && found+=("$f")
done
if [ "${#found[@]}" -ne 1 ]; then
    echo "::error::expected exactly one installed bin/$program for ${ns}:${name}, found ${#found[@]}: ${found[*]:-none}"
    ls -R "$HOME/.xlings/data/xpkgs/${ns}-x-$name" 2>/dev/null | head -40 || true
    exit 1
fi
if [ ! -x "${found[0]}" ]; then
    echo "::error::${found[0]} is not executable"
    exit 1
fi
echo "installed: ${found[0]}"
echo "$variable=${found[0]}" >> "$GITHUB_ENV"
