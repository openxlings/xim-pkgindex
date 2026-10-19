#!/bin/sh
# A large Qt desktop's tree on luban:qt-runtime (tools/res/build.sh kde), in
# the Alpine 3.24 container, taken from every package its own packages
# brought beyond the runtime's -- as Alpine lays them out under /usr, so that
# a Luban system's /usr (which projects a package's bin, libexec, lib/<dir>
# and share) has them where they were built to be:
#
#   libexec/<name>/bin/   the programs of /usr/bin (bin/<program> runs each)
#   libexec/<name>/lib/   every library they and the rest link but the runtime's, the musl loader
#   libexec/<name>/plugins, qml/   the Qt plugins and QML modules that are not the runtime's
#   libexec/..., lib/<dir>/...     /usr/libexec and /usr/lib/<dir> as they are (helpers by path)
#   share/, etc/xdg/               what the packages place for everyone
#
#   sh desktop-auto.sh <tree> <name> "<the runtime's apks>" "<the desktop's apks>"
set -eu
tree="$1"; name="$2"; runtime="$3"; desktop="$4"
x="$tree/libexec/$name"
mkdir -p "$tree/bin" "$x/bin" "$x/lib" "$x/plugins" "$x/qml" "$tree/share/licenses" "$tree/etc/xdg"
say() { printf '[desktop-auto] %s\n' "$*" >&2; }
# A trigger that fails (a cache a container has no use for) is not the
# packages: what was asked for is checked to be there instead.
# shellcheck disable=SC2086
apk add -q $runtime || say "apk add (runtime) returned $?" # host-dep-ok: the factory's Alpine container (tools/res/build.sh)
apk info -q | sort > /tmp/before
# shellcheck disable=SC2086
apk add -q $desktop || say "apk add (desktop) returned $?" # host-dep-ok: the factory's Alpine container
for p in $runtime $desktop; do apk info -e "$p" >/dev/null || { say "$p is not installed"; exit 1; }; done
apk info -q | sort > /tmp/after
say "$(comm -13 /tmp/before /tmp/after | wc -l) packages beyond the runtime's"
comm -13 /tmp/before /tmp/after > /tmp/carried
# shellcheck disable=SC2086
sh /w/tree.sh /w/rt-root/libexec/qt-runtime $runtime
ls /w/rt-root/libexec/qt-runtime/lib > /tmp/rt-names
say "the runtime: $(wc -l < /tmp/rt-names) libraries"
is_elf() { [ "$(head -c 4 "$1" 2>/dev/null | od -An -c | tr -d ' \n')" = '177ELF' ]; }
# shellcheck disable=SC2046
apk info -qL $(cat /tmp/carried) 2>/dev/null | grep -Ev '^usr/share/(man|doc|info|gtk-doc|help)/|^usr/include/|\.a$|/pkgconfig/|/cmake/' \
    | sort -u > /tmp/files
while read -r f; do
    [ -f "/$f" ] || [ -L "/$f" ] || continue
    case "$f" in
        usr/bin/*)
            if is_elf "/$f"; then cp -L "/$f" "$x/bin/"; echo "${f#usr/bin/}" >> /w/programs
            else cp -a "/$f" "$tree/bin/"; fi ;;
        usr/sbin/*) ;;
        usr/lib/qt6/plugins/*)
            rel="${f#usr/lib/qt6/plugins/}"
            [ -e "/w/rt-root/libexec/qt-runtime/plugins/$rel" ] && continue
            mkdir -p "$x/plugins/$(dirname "$rel")"; cp -a "/$f" "$x/plugins/$rel" ;;
        usr/lib/qt6/qml/*)
            rel="${f#usr/lib/qt6/qml/}"
            [ -e "/w/rt-root/libexec/qt-runtime/qml/$rel" ] && continue
            mkdir -p "$x/qml/$(dirname "$rel")"; cp -a "/$f" "$x/qml/$rel" ;;
        usr/lib/qt6/*|usr/lib/qt5/*) ;;
        usr/lib/*/*)
            mkdir -p "$tree/$(dirname "${f#usr/}")"; cp -a "/$f" "$tree/${f#usr/}" ;;
        usr/lib/*) ;;   # its libraries: by what links them, under the names they are linked by (below)
        usr/libexec/*)
            mkdir -p "$tree/$(dirname "${f#usr/}")"; cp -a "/$f" "$tree/${f#usr/}" ;;
        usr/share/licenses/*) ;;
        usr/share/*|etc/xdg/*)
            rel="${f#usr/}"
            mkdir -p "$tree/$(dirname "$rel")"; cp -a "/$f" "$tree/$rel" ;;
    esac
done < /tmp/files
while read -r p; do [ ! -d "/usr/share/licenses/$p" ] || cp -r "/usr/share/licenses/$p" "$tree/share/licenses/"; done < /tmp/carried
# The MIME database its file types are read from (a system may have none).
[ ! -d /usr/share/mime ] || { mkdir -p "$tree/share/mime"; cp -a /usr/share/mime/. "$tree/share/mime/"; }
say "files placed; now the libraries"
# Every library anything here links, but the runtime's.
find "$tree" -type f | while read -r f; do if is_elf "$f"; then echo "$f"; fi; done > /tmp/elfs
while read -r f; do ldd "$f" 2>/dev/null | awk '/=>/ { print $3 }'; done < /tmp/elfs | sort -u > /tmp/libs
while read -r l; do
    b="$(basename "$l")"
    grep -qx "$b" /tmp/rt-names || [ -e "$x/lib/$b" ] || cp -L "$l" "$x/lib/"
done < /tmp/libs
cp -L "/lib/ld-musl-$(uname -m).so.1" "$x/lib/"
ln -sf "ld-musl-$(uname -m).so.1" "$x/lib/libc.musl-$(uname -m).so.1"
cp /tmp/carried /w/carried
