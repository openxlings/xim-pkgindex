#!/usr/bin/env python3
"""The libc++ module sources of an Android NDK release, for the hosts whose
archive omits them (docs/android-ndk-libcxx-modules.md).

    libcxx_modules.py probe <archive-or-url>...
        Which archives carry share/libc++/v1, the clang revision of each, and
        whether their libc++ headers agree. A URL is read with HTTP range
        requests (the zip's central directory and a few small members), so a
        new release is assessed without downloading it.

    libcxx_modules.py extract <version> <with-sources.zip> <without.zip> <dir>
        Checks that both archives are the release <version> (Pkg.Revision),
        built from one clang revision with byte-identical libc++ headers, and
        that the second lacks the module sources; then writes the first's
        share/libc++/v1 into <dir>, with MANIFEST (sha256 and path of each
        file, sorted) and the release's NOTICE.toolchain.

Only the standard library: tools/res/build.sh runs it on the runner.
"""
from __future__ import annotations

import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

SURFACE = "share/libc++/v1/"
HEADERS = "sysroot/usr/include/c++/v1/"


class Remote(io.RawIOBase):
    """A seekable read-only file over HTTP range requests."""

    def __init__(self, url: str):
        self.url, self.pos = url, 0
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request) as response:
            self.size = int(response.headers["Content-Length"])

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        base = {io.SEEK_SET: 0, io.SEEK_CUR: self.pos, io.SEEK_END: self.size}[whence]
        self.pos = base + offset
        return self.pos

    def readinto(self, buffer) -> int:
        if self.pos >= self.size:
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(request) as response:
            data = response.read()
        buffer[: len(data)] = data
        self.pos += len(data)
        return len(data)


class Release:
    """One NDK archive: its root directory, its host's toolchain, its members."""

    def __init__(self, source: str):
        self.source = source
        raw = Remote(source) if source.startswith(("http://", "https://")) else open(source, "rb")
        self.zip = zipfile.ZipFile(io.BufferedReader(raw, buffer_size=1 << 20) if isinstance(raw, Remote) else raw)
        names = self.zip.namelist()
        self.root = names[0].split("/", 1)[0] + "/"
        hosts = {n.split("/")[4] for n in names if n.startswith(self.root + "toolchains/llvm/prebuilt/") and n.count("/") > 4}
        if len(hosts) != 1:
            raise SystemExit(f"{source}: expected one prebuilt host, found {sorted(hosts)}")
        self.toolchain = f"{self.root}toolchains/llvm/prebuilt/{hosts.pop()}/"
        self.files = {n: self.zip.getinfo(n) for n in names if not n.endswith("/")}

    def under(self, prefix: str) -> dict[str, zipfile.ZipInfo]:
        start = self.toolchain + prefix
        return {n[len(start):]: i for n, i in self.files.items() if n.startswith(start)}

    def text(self, name: str) -> str:
        return self.zip.read(self.root + name).decode()

    def revision(self) -> str:
        for line in self.text("source.properties").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "Pkg.Revision":
                return value.strip()
        raise SystemExit(f"{self.source}: no Pkg.Revision in source.properties")

    def clang(self) -> str:
        return self.zip.read(self.toolchain + "AndroidVersion.txt").decode().strip()


def differing_headers(a: Release, b: Release, by_content: bool) -> list[str]:
    ha, hb = a.under(HEADERS), b.under(HEADERS)
    if set(ha) != set(hb):
        return sorted(set(ha) ^ set(hb))
    if by_content:
        return sorted(n for n in ha if a.zip.read(ha[n]) != b.zip.read(hb[n]))
    return sorted(n for n in ha if ha[n].CRC != hb[n].CRC or ha[n].file_size != hb[n].file_size)


def probe(sources: list[str]) -> int:
    releases = [Release(s) for s in sources]
    for r in releases:
        surface = r.under(SURFACE)
        print(f"{Path(r.source).name}: Pkg.Revision {r.revision()}, clang {r.clang().splitlines()[0]}, "
              f"{len(r.files)} files, {r.toolchain.split('/')[-2]}, {len(r.under(HEADERS))} libc++ headers, "
              f"module sources {'present (%d files)' % len(surface) if surface else 'ABSENT'}")
    first = releases[0]
    for r in releases[1:]:
        same_clang = r.clang() == first.clang()
        differ = differing_headers(first, r, by_content=False)
        print(f"{Path(r.source).name} against {Path(first.source).name}: clang {'same' if same_clang else 'DIFFERENT'}, "
              f"libc++ headers {'identical (by CRC)' if not differ else 'DIFFERENT: ' + ', '.join(differ[:10])}")
    return 0


def extract(version: str, with_sources: str, without: str, out: str) -> int:
    a, b = Release(with_sources), Release(without)
    for r in (a, b):
        if r.revision() != version:
            raise SystemExit(f"{r.source} is Pkg.Revision {r.revision()}, not {version}")
    if a.clang() != b.clang():
        raise SystemExit("the two archives were built from different clang revisions")
    differ = differing_headers(a, b, by_content=True)
    if differ:
        raise SystemExit(f"the two archives' libc++ headers differ: {', '.join(differ[:10])}")
    surface = a.under(SURFACE)
    if not surface or "std.cppm" not in surface or "std.compat.cppm" not in surface:
        raise SystemExit(f"{a.source} carries no module sources under {SURFACE}")
    if b.under(SURFACE):
        raise SystemExit(f"{b.source} carries its own module sources; this package is not needed for it")
    target = Path(out)
    manifest = []
    for name in sorted(surface):
        data = a.zip.read(surface[name])
        path = target / SURFACE / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(0o644)
        manifest.append(f"{hashlib.sha256(data).hexdigest()}  {SURFACE}{name}\n")
    (target / "MANIFEST").write_text("".join(manifest))
    licenses = target / "share/licenses/android-ndk-libcxx-modules"
    licenses.mkdir(parents=True, exist_ok=True)
    (licenses / "NOTICE.toolchain").write_text(a.text("NOTICE.toolchain"))
    print(f"{len(manifest)} files, clang {a.clang().splitlines()[0]}, {len(a.under(HEADERS))} identical libc++ headers")
    return 0


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "probe":
        sys.exit(probe(sys.argv[2:]))
    if len(sys.argv) == 6 and sys.argv[1] == "extract":
        sys.exit(extract(*sys.argv[2:]))
    sys.exit(__doc__)
