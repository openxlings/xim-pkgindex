#!/usr/bin/env bash
# install-recipe.sh <recipe> <program> <variable>
#
# Registers the recipe from this checkout under `local:`, installs it, and
# publishes the installed program's path as <variable> to the following
# steps. The program is addressed by its store path, which is the file the
# install hook wrote, rather than by a shim whose target a later install could
# change.
set -euo pipefail
recipe="$1"; program="$2"; variable="$3"
name="$(basename "$recipe" .lua)"
xlings="$HOME/.xlings/bin/xlings"

"$xlings" config --add-xpkg "$recipe"
"$xlings" install "local:$name" -y

found=()
for f in "$HOME/.xlings/data/xpkgs/local-x-$name"/*/bin/"$program"; do
    [ -f "$f" ] && found+=("$f")
done
if [ "${#found[@]}" -ne 1 ]; then
    echo "::error::expected exactly one installed bin/$program for local:$name, found ${#found[@]}: ${found[*]:-none}"
    ls -R "$HOME/.xlings/data/xpkgs/local-x-$name" 2>/dev/null | head -40 || true
    exit 1
fi
if [ ! -x "${found[0]}" ]; then
    echo "::error::${found[0]} is not executable"
    exit 1
fi
echo "installed: ${found[0]}"
echo "$variable=${found[0]}" >> "$GITHUB_ENV"
