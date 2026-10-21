#!/bin/sh
# A Qt desktop's tree on luban:qt-runtime, in the Alpine 3.24 container
# (tools/res/build.sh lxqt, kde): its programs, the Qt plugins and QML modules
# that are not the runtime's, the files its packages place in /usr/share and
# /etc/xdg, and every library they link that the runtime does not have.
#
#   sh desktop.sh <tree> <name> "<the runtime's apks>" "<programs>" "<packages whose share and etc/xdg it carries>"
#
# The runtime's own tree is made beside it (/w/rt-root/libexec/qt-runtime) by
# the same tree.sh the runtime's build runs.
set -eu
tree="$1"; name="$2"; runtime="$3"; progs="$4"; carried="$5"
x="$tree/libexec/$name"
mkdir -p "$tree/bin" "$x/bin" "$x/lib" "$x/plugins" "$x/qml" "$tree/share/licenses" "$tree/etc/xdg"
# shellcheck disable=SC2086
sh /w/tree.sh /w/rt-root/libexec/qt-runtime $runtime
ls /w/rt-root/libexec/qt-runtime/lib > /tmp/rt-names
for p in $progs; do cp -L "$p" "$x/bin/"; done
# The plugins and QML modules the runtime does not have are the desktop's.
for kind in plugins qml; do
    [ -d "/usr/lib/qt6/$kind" ] || continue
    (cd "/usr/lib/qt6/$kind" && find . -type f) | while read -r f; do
        [ -e "/w/rt-root/libexec/qt-runtime/$kind/$f" ] && continue
        mkdir -p "$x/$kind/$(dirname "$f")"
        cp -a "/usr/lib/qt6/$kind/$f" "$x/$kind/$f"
    done
done
# What its packages place for everyone: data, defaults, sessions' services.
# shellcheck disable=SC2086
apk info -qL $carried 2>/dev/null | grep -E '^(usr/share|etc/xdg)/' \
    | grep -Ev '^usr/share/(man|doc|info|locale|licenses|gtk-doc)/' > /tmp/carried || true
while read -r f; do
    case "$f" in
        usr/share/*) rel="share/${f#usr/share/}" ;;
        etc/xdg/*) rel="etc/xdg/${f#etc/xdg/}" ;;
    esac
    mkdir -p "$tree/$(dirname "$rel")"
    cp -a "/$f" "$tree/$rel"
done < /tmp/carried
for p in $carried; do [ ! -d "/usr/share/licenses/$p" ] || cp -r "/usr/share/licenses/$p" "$tree/share/licenses/"; done
# Every library its programs, plugins and lib/ (a browser has none) link, but the runtime's.
{ for p in $progs; do echo "$p"; done; find "$x/plugins" "$x/qml" "$tree/lib" -name '*.so*' -type f 2>/dev/null || true; } > /tmp/elfs
while read -r f; do ldd "$f" 2>/dev/null | awk '/=>/ { print $3 }'; done < /tmp/elfs | sort -u > /tmp/libs
while read -r l; do grep -qx "$(basename "$l")" /tmp/rt-names || cp -L "$l" "$x/lib/"; done < /tmp/libs
cp -L "/lib/ld-musl-$(uname -m).so.1" "$x/lib/"
# musl's loader is its libc too: the name a program links it by.
ln -sf "ld-musl-$(uname -m).so.1" "$x/lib/libc.musl-$(uname -m).so.1"
# The MIME database its file types are read from (a system may have none).
[ ! -d /usr/share/mime ] || { mkdir -p "$tree/share/mime"; cp -a /usr/share/mime/. "$tree/share/mime/"; }
