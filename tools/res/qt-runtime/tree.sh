#!/bin/sh
# luban:qt-runtime's tree, in the Alpine 3.24 container (tools/res/build.sh):
# the Qt libraries, the plugins and QML modules of the runtime's own packages,
# every library they link, and the musl loader. A Qt desktop's build makes the
# same tree to know which libraries and plugins are the runtime's.
#
#   sh tree.sh <dir> <the runtime's apk packages...>    # <dir>/lib, /plugins, /qml
set -eu
dir="$1"; shift
mkdir -p "$dir/lib" "$dir/plugins" "$dir/qml"
# Only the runtime's packages' plugins and QML: another package's (a
# desktop's platform theme) is that desktop's.
apk info -qL "$@" 2>/dev/null | grep -E '^usr/lib/qt6/(plugins|qml)/' > /tmp/rt-owned || true
while read -r f; do
    case "$f" in
        usr/lib/qt6/plugins/*) rel="plugins/${f#usr/lib/qt6/plugins/}" ;;
        usr/lib/qt6/qml/*) rel="qml/${f#usr/lib/qt6/qml/}" ;;
    esac
    mkdir -p "$dir/$(dirname "$rel")"
    cp -a "/$f" "$dir/$rel"
done < /tmp/rt-owned
{ apk info -qL "$@" 2>/dev/null | grep -E '^usr/lib/libQt6[^/]*\.so\.6$' | sed 's|^|/|'; find "$dir/plugins" "$dir/qml" -name '*.so'; } > /tmp/rt-elfs
while read -r f; do
    case "$f" in /usr/*) echo "$f" ;; esac
    ldd "$f" 2>/dev/null | awk '/=>/ { print $3 }'
done < /tmp/rt-elfs | sort -u > /tmp/rt-libs
while read -r l; do cp -L "$l" "$dir/lib/"; done < /tmp/rt-libs
cp -L "/lib/ld-musl-$(uname -m).so.1" "$dir/lib/"
