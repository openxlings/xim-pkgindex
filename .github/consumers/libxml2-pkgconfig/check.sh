#!/usr/bin/env bash
# libxml2 2.13.5-1 publishes `libxml-2.0.pc` into the SubOS pkg-config view,
# relocated to the payload, and pkg-config resolves the package from the view
# alone.
set -uo pipefail
: "${REGISTRY:?}"
fail() { echo "::error::libxml2-pkgconfig: $*"; exit 1; }
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

payload="$REGISTRY/data/xpkgs/xim-x-libxml2/2.13.5-1"
pc="$payload/lib/pkgconfig/libxml-2.0.pc"
view="$REGISTRY/subos/default/usr/lib/pkgconfig"

[ -f "$pc" ] || fail "$pc is absent"
prefix_line=$(sed -n 's/^prefix=//p' "$pc")
echo "READING libxml2.prefix: $prefix_line"
[ "$prefix_line" = "$payload" ] || fail "the .pc prefix is '$prefix_line', not the payload"

[ -e "$view/libxml-2.0.pc" ] || fail "the view $view holds no libxml-2.0.pc"
echo "READING libxml2.view: $(ls -l "$view/libxml-2.0.pc")"

cflags=$(PKG_CONFIG_LIBDIR="$view" pkg-config --cflags libxml-2.0) || fail "pkg-config --cflags libxml-2.0 failed against the view"
libs=$(PKG_CONFIG_LIBDIR="$view" pkg-config --libs libxml-2.0) || fail "pkg-config --libs libxml-2.0 failed against the view"
echo "READING libxml2.cflags: $cflags"
echo "READING libxml2.libs: $libs"
contains "$cflags" "-I$payload/include/libxml2" || fail "--cflags does not name the payload's include/libxml2"
contains "$libs" "-L$payload/lib" || fail "--libs does not name the payload's lib"
contains "$libs" "-lxml2" || fail "--libs does not name -lxml2"
[ -f "$payload/include/libxml2/libxml/parser.h" ] || fail "the include directory the .pc names has no libxml/parser.h"

# The control: an empty directory resolves nothing, so the criteria above
# measured the view.
empty=$(mktemp -d)
if PKG_CONFIG_LIBDIR="$empty" pkg-config --cflags libxml-2.0 > /dev/null 2>&1; then
    fail "pkg-config resolved libxml-2.0 from an empty directory; the view criterion measures nothing"
fi
echo "libxml2-pkgconfig: every criterion held"
