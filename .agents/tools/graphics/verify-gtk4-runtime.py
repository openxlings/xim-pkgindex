#!/usr/bin/env python3
"""Native, fail-closed acceptance for an installed gtk4-runtime payload.

Usage (on each real architecture, after relocate.apply + selfcontain.seal):
  xvfb-run -a python3 verify-gtk4-runtime.py --runtime-root DIR \
      --libc-root GLIBC_PROVIDER_DIR --arch aarch64 [--consumer-root DBPP_DIR]

Requires Python 3, native cc with libc development headers, a functioning display
(Xvfb + xauth suffices), and fonts/data in the runtime. No GTK SDK/Python GI is
needed. --libc-root is deliberately explicit: /usr and host loader caches are not
providers. The verifier never sets LD_LIBRARY_PATH or repairs installed RPATHs.
It preserves the caller environment; LD_AUDIT/LD_PRELOAD contamination is refused.
Exit: 0 all checks including GUI passed; 1 broken; 2 usage; 3 prerequisite absent
(including missing display or libc-root). 3 is NOT successful acceptance.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile


class Broken(RuntimeError):
    """An installed payload failed acceptance."""


class Prerequisite(RuntimeError):
    """Acceptance could not be completed; never a passing verdict."""


MACHINES = {"x86_64": 62, "aarch64": 183}
CRT = frozenset({
    "libc.so.6", "libm.so.6", "libdl.so.2", "libpthread.so.0", "librt.so.1",
    "libresolv.so.2", "libutil.so.1", "libanl.so.1", "libBrokenLocale.so.1",
    "libmvec.so.1",
    "libnss_files.so.2", "libnss_dns.so.2", "libnss_compat.so.2",
    "libnss_hesiod.so.2", "libthread_db.so.1",
    "ld-linux-x86-64.so.2", "ld-linux-aarch64.so.1",
})
CRITICAL = (
    "libgtk-4.so.1", "libpango-1.0.so.0", "libpangocairo-1.0.so.0",
    "libcairo.so.2", "libgraphene-1.0.so.0", "libgdk_pixbuf-2.0.so.0",
    "libglib-2.0.so.0", "libgobject-2.0.so.0", "libgio-2.0.so.0",
    "libsoup-3.0.so.0", "libvulkan.so.1",
)


@dataclass(frozen=True)
class Elf:
    path: Path
    needed: tuple[str, ...]
    soname: str | None
    runpath: tuple[str, ...]
    interp: str | None


def inside(path: Path, root: Path) -> bool:
    return path.resolve().is_relative_to(root.resolve())


def read_elf(path: Path, arch: str) -> Elf | None:
    """Read ELF64 program/dynamic tables, not filename suffixes or ldd output."""
    with path.open("rb") as stream:
        head = stream.read(64)
        if head[:4] != b"\x7fELF":
            return None
        if len(head) < 64 or head[4:6] != b"\x02\x01":
            raise Broken(f"not a little-endian ELF64 object: {path}")
        machine = struct.unpack_from("<H", head, 18)[0]
        if machine != MACHINES[arch]:
            raise Broken(f"wrong ELF architecture: {path}: e_machine={machine}, wanted {arch}")
        stream.seek(0)
        data = stream.read()
    try:
        phoff = struct.unpack_from("<Q", data, 32)[0]
        entsize, count = struct.unpack_from("<HH", data, 54)
        if count and entsize != 56:
            raise Broken(f"invalid ELF program headers: {path}")
        loads, dynamic, interp = [], None, None
        for i in range(count):
            kind, _, off, va, _, size, _, _ = struct.unpack_from("<IIQQQQQQ", data, phoff + i * entsize)
            if off + size > len(data):
                raise Broken(f"truncated ELF segment: {path}")
            if kind == 1:
                loads.append((va, off, size))
            elif kind == 2:
                dynamic = (off, size)
            elif kind == 3:
                interp = data[off:off + size].rstrip(b"\0").decode()
        tags: dict[int, list[int]] = {}
        if dynamic:
            off, size = dynamic
            for pos in range(off, off + size, 16):
                tag, value = struct.unpack_from("<qQ", data, pos)
                if tag == 0:
                    break
                tags.setdefault(tag, []).append(value)
        if not tags:
            return Elf(path.resolve(), (), None, (), interp)
        va = tags[5][0]
        strbase = next(off + va - base for base, off, size in loads if base <= va < base + size)
        strsize = tags[10][0]
        if strbase + strsize > len(data):
            raise Broken(f"truncated ELF string table: {path}")

        def string(offset):
            if offset >= strsize:
                raise Broken(f"invalid ELF string offset: {path}")
            end = data.index(b"\0", strbase + offset, strbase + strsize)
            return data[strbase + offset:end].decode()

        needed = tuple(string(n) for n in tags.get(1, []))
        soname = string(tags[14][0]) if 14 in tags else None
        search = tags.get(29, tags.get(15, []))
        runpath = tuple(string(search[0]).split(":")) if search else ()
        return Elf(path.resolve(), needed, soname, runpath, interp)
    except (struct.error, KeyError, StopIteration, ValueError, UnicodeError) as exc:
        raise Broken(f"malformed ELF {path}: {exc}") from exc


def scan(root: Path, arch: str) -> dict[Path, Elf]:
    if not root.is_dir():
        raise Broken(f"missing payload root: {root}")
    objects = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink() and (not path.exists() or not inside(path, root)):
            raise Broken(f"broken or escaping payload symlink: {path}")
        if path.is_file() and path.resolve() not in objects:
            obj = read_elf(path, arch)
            if obj:
                objects[obj.path] = obj
    if not objects:
        raise Broken(f"no actual ELF objects in {root}")
    return objects


def providers(objects: dict[Path, Elf]) -> dict[str, Path]:
    result = {}
    for obj in objects.values():
        for name in {obj.path.name, obj.soname} - {None}:
            previous = result.get(name)
            if previous and previous != obj.path:
                raise Broken(f"ambiguous provider for {name}: {previous}, {obj.path}")
            result[name] = obj.path
    return result


def check_closure(objects: dict[Path, Elf], libc: dict[str, Path], roots: tuple[Path, ...]):
    """Resolve each object's own search paths, never the host cache or a union map."""
    for obj in objects.values():
        for needed in obj.needed:
            if "/" in needed:
                raise Broken(f"non-SONAME DT_NEEDED in {obj.path}: {needed}")
            if needed in CRT:
                if needed not in libc:
                    raise Broken(f"missing explicit glibc provider for {needed}, needed by {obj.path}")
                continue
            found = None
            for entry in obj.runpath:
                expanded = entry.replace("${ORIGIN}", str(obj.path.parent)).replace("$ORIGIN", str(obj.path.parent))
                if not expanded or "$" in expanded or not Path(expanded).is_absolute():
                    raise Broken(f"unsealed search path in {obj.path}: {entry!r}")
                candidate = Path(expanded) / needed
                if candidate.is_file():
                    if not any(inside(candidate, root) for root in roots):
                        raise Broken(f"outside provider for {needed}: {candidate}")
                    if candidate.resolve() not in objects:
                        raise Broken(f"non-ELF provider for {needed}: {candidate}")
                    provider = objects[candidate.resolve()]
                    if provider.soname is not None and provider.soname != needed:
                        raise Broken(f"wrong SONAME provider for {needed}: {candidate} has {provider.soname}")
                    found = candidate
                    break
            if found is None:
                raise Broken(f"missing dependency in sealed RUNPATH: {obj.path} needs {needed}")


def check_relocated(root: Path):
    manifest = root / "RELOCATE.json"
    if not manifest.is_file():
        raise Broken(f"missing relocation manifest: {manifest}")
    data = json.loads(manifest.read_text())
    if data.get("schema") != 1 or not isinstance(data.get("entries"), list):
        raise Broken(f"invalid relocation manifest: {manifest}")
    for entry in data["entries"]:
        path = root / entry["path"]
        if not inside(path, root) or not path.is_file():
            raise Broken(f"invalid relocation target: {path}")
        placeholder = entry["placeholder"].encode()
        if not placeholder or placeholder in path.read_bytes():
            raise Broken(f"unapplied relocation in {path}")


# LD_AUDIT records dlopen too (GIO TLS, pixbuf loaders, graphics backends), not just
# initial DT_NEEDED. The parent rejects every object outside the explicit roots.
AUDITOR = r'''
#define _GNU_SOURCE
#include <link.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
unsigned int la_version(unsigned int v) { return LAV_CURRENT; }
unsigned int la_objopen(struct link_map *m, Lmid_t ns, uintptr_t *cookie) {
    const char *file = getenv("GTK_RUNTIME_AUDIT_LOG");
    if (!file) _exit(90);
    int fd = open(file, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) _exit(91);
    if (m->l_name && *m->l_name) {
        write(fd, m->l_name, strlen(m->l_name)); write(fd, "\n", 1);
    }
    close(fd);
    return 0;
}
'''

# ABI-only declarations keep this probe independent of a host GTK SDK.
PROBE = r'''
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#define FN(ret, name, args) ret (*name) args = (ret (*) args) symbol(#name)
static void *symbol(const char *name) {
    void *p = dlsym(RTLD_DEFAULT, name);
    if (!p) { fprintf(stderr, "missing symbol %s: %s\n", name, dlerror()); exit(1); }
    return p;
}
static void require(int yes, const char *why) {
    if (!yes) { fprintf(stderr, "%s\n", why); exit(1); }
}
int main(int argc, char **argv) {
    require(argc > 3, "expected PNG output and absolute runtime library paths");
    for (int i = 2; i < argc; ++i) {
        if (!dlopen(argv[i], RTLD_NOW | RTLD_GLOBAL)) {
            fprintf(stderr, "dlopen %s: %s\n", argv[i], dlerror()); return 1;
        }
    }
    FN(void *, g_tls_backend_get_default, (void));
    FN(int, g_tls_backend_supports_tls, (void *));
    FN(unsigned long, g_tls_backend_get_certificate_type, (void *));
    FN(const char *, g_type_name, (unsigned long));
    void *tls = g_tls_backend_get_default();
    require(tls && g_tls_backend_supports_tls(tls), "GIO has no real TLS backend");
    printf("TLS=%s\n", g_type_name(g_tls_backend_get_certificate_type(tls)));
    FN(void *, gdk_pixbuf_new, (int, int, int, int, int));
    FN(void, gdk_pixbuf_fill, (void *, unsigned int));
    FN(int, gdk_pixbuf_save, (void *, const char *, const char *, void **, ...));
    FN(void *, gdk_pixbuf_new_from_file, (const char *, void **));
    FN(int, gdk_pixbuf_get_width, (void *));
    FN(int, gdk_pixbuf_get_height, (void *));
    FN(unsigned char *, gdk_pixbuf_get_pixels, (void *));
    FN(void, g_object_unref, (void *));
    void *error = NULL;
    void *pixbuf = gdk_pixbuf_new(0, 1, 8, 2, 2);
    require(pixbuf != NULL, "pixbuf allocation failed");
    gdk_pixbuf_fill(pixbuf, 0x336699ff);
    require(gdk_pixbuf_save(pixbuf, argv[1], "png", &error, NULL), "PNG encoder failed");
    void *decoded = gdk_pixbuf_new_from_file(argv[1], &error);
    require(decoded && gdk_pixbuf_get_width(decoded) == 2 && gdk_pixbuf_get_height(decoded) == 2,
            "PNG decoder failed");
    unsigned char *pixel = gdk_pixbuf_get_pixels(decoded);
    require(pixel && pixel[0] == 0x33 && pixel[1] == 0x66 && pixel[2] == 0x99, "PNG pixel mismatch");
    g_object_unref(decoded); g_object_unref(pixbuf);
    FN(int, gtk_init_check, (void));
    require(gtk_init_check(), "GTK display initialization failed (display is REQUIRED)");
    FN(void *, gtk_window_new, (void));
    FN(void *, gtk_label_new, (const char *));
    FN(void, gtk_window_set_child, (void *, void *));
    FN(void, gtk_window_set_default_size, (void *, int, int));
    FN(void, gtk_window_present, (void *));
    FN(void, gtk_window_destroy, (void *));
    FN(int, g_main_context_iteration, (void *, int));
    FN(int, gtk_widget_get_width, (void *));
    FN(void *, gtk_label_get_layout, (void *));
    FN(void *, pango_layout_get_context, (void *));
    FN(const void *, pango_context_get_font_description, (void *));
    FN(void *, pango_context_load_font, (void *, const void *));
    FN(void *, pango_fc_font_get_pattern, (void *));
    FN(int, FcPatternGetString, (void *, const char *, int, unsigned char **));
    FN(void *, gtk_snapshot_new, (void));
    FN(void, gtk_widget_snapshot_child, (void *, void *, void *));
    FN(void *, gtk_snapshot_free_to_node, (void *));
    FN(void, gsk_render_node_draw, (void *, void *));
    FN(void, gsk_render_node_unref, (void *));
    FN(void *, cairo_image_surface_create, (int, int, int));
    FN(void *, cairo_create, (void *));
    FN(int, cairo_status, (void *));
    FN(void, cairo_surface_flush, (void *));
    FN(unsigned char *, cairo_image_surface_get_data, (void *));
    FN(int, cairo_image_surface_get_stride, (void *));
    FN(int, cairo_surface_write_to_png, (void *, const char *));
    FN(void, cairo_destroy, (void *));
    FN(void, cairo_surface_destroy, (void *));
    void *window = gtk_window_new(), *label = gtk_label_new("GTK4 runtime: Pango Cairo TLS PNG");
    gtk_window_set_child(window, label); gtk_window_set_default_size(window, 420, 100);
    gtk_window_present(window);
    for (int i = 0; i < 100; ++i) {
        for (int j = 0; j < 100 && g_main_context_iteration(NULL, 0); ++j) {}
        usleep(10000);
    }
    require(gtk_widget_get_width(label) > 0, "GTK label was not allocated");
    void *context = pango_layout_get_context(gtk_label_get_layout(label));
    void *font = pango_context_load_font(context, pango_context_get_font_description(context));
    require(font != NULL, "Pango could not load a real font");
    unsigned char *fontfile = NULL;
    require(FcPatternGetString(pango_fc_font_get_pattern(font), "file", 0, &fontfile) == 0,
            "Pango font has no real Fontconfig file provider");
    char fontpath[4096];
    const char *root = getenv("GTK_RUNTIME_EXPECT_ROOT");
    require(root && realpath((char *)fontfile, fontpath), "font file does not exist");
    require(!strncmp(fontpath, root, strlen(root)) && fontpath[strlen(root)] == '/',
            "Pango silently used a host font instead of runtime-owned font/data paths");
    printf("FONT=%s\n", fontpath);
    g_object_unref(font);
    void *snapshot = gtk_snapshot_new();
    gtk_widget_snapshot_child(window, label, snapshot);
    void *node = gtk_snapshot_free_to_node(snapshot);
    require(node != NULL, "GTK text/widget snapshot produced no render node (check fonts/data)");
    void *surface = cairo_image_surface_create(0, 420, 100), *cr = cairo_create(surface);
    gsk_render_node_draw(node, cr);
    require(cairo_status(cr) == 0, "GTK render node drawing failed");
    cairo_surface_flush(surface);
    unsigned char *rendered = cairo_image_surface_get_data(surface);
    int stride = cairo_image_surface_get_stride(surface), nonempty = 0;
    for (int i = 0; i < stride * 100; ++i) nonempty |= rendered[i];
    require(nonempty, "GTK label rendering was blank");
    char output[4096];
    require(snprintf(output, sizeof output, "%s.render.png", argv[1]) < sizeof output, "output path too long");
    require(cairo_surface_write_to_png(surface, output) == 0, "GTK render PNG write failed");
    cairo_destroy(cr); cairo_surface_destroy(surface); gsk_render_node_unref(node);
    gtk_window_destroy(window);
    puts("PASS: GTK initialized and rendered; GIO TLS backend; PNG encode/decode");
    return 0;
}
'''


def check_loaded(log: Path, objects: dict[Path, Elf], libc: dict[str, Path], extra: set[Path]):
    if not log.is_file() or not log.stat().st_size:
        raise Broken("loader audit produced no evidence")
    allowed = set(objects) | set(libc.values()) | extra
    loaded = set()
    for line in log.read_text().splitlines():
        if line.startswith("linux-vdso.so."):
            continue
        if not Path(line).is_absolute():
            raise Broken(f"non-absolute loaded object: {line}")
        path = Path(line).resolve()
        if path not in allowed:
            raise Broken(f"host/outside library was actually loaded: {line}")
        loaded.add(path)
    return loaded


def run_native(root: Path, libc_root: Path, arch: str, objects: dict[Path, Elf],
               libc: dict[str, Path], critical: dict[str, Path], consumer: Path | None):
    if platform.system() != "Linux" or platform.machine() != arch:
        raise Prerequisite(f"requires native Linux/{arch}, got {platform.system()}/{platform.machine()}")
    cc = shutil.which("cc")
    if not cc:
        raise Prerequisite("native cc and libc development headers are required")
    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        raise Prerequisite("display required: run under xvfb-run -a (needs Xvfb and xauth)")
    if os.environ.get("LD_PRELOAD") or os.environ.get("LD_AUDIT"):
        raise Prerequisite("LD_PRELOAD/LD_AUDIT is already set; use an uncontaminated invocation")
    loader_name = "ld-linux-x86-64.so.2" if arch == "x86_64" else "ld-linux-aarch64.so.1"
    loader = libc.get(loader_name)
    if loader is None or "libc.so.6" not in libc:
        raise Broken(f"explicit glibc provider lacks {loader_name} or libc.so.6: {libc_root}")
    with tempfile.TemporaryDirectory(prefix="gtk4-verify-") as work:
        work = Path(work)
        audit, probe = work / "audit.so", work / "probe"
        # Only the probe itself gets a RUNPATH. DT_RUNPATH is non-transitive:
        # dependencies and modules must use their installed seal, not this path.
        rpath = ":".join(sorted({str(p.parent) for p in libc.values()}))
        for name, source, output, flags in (
            ("audit.c", AUDITOR, audit, ["-shared", "-fPIC"]),
            ("probe.c", PROBE, probe, ["-ldl"]),
        ):
            src = work / name
            src.write_text(source)
            result = subprocess.run([cc, str(src), "-o", str(output), *flags,
                                     "-Wl,--enable-new-dtags", f"-Wl,-rpath,{rpath}"],
                                    text=True, capture_output=True, timeout=60)
            if result.returncode:
                raise Broken(f"native probe compilation failed:\n{result.stdout}{result.stderr}")
        log = work / "loaded.log"
        env = {**os.environ, "LD_AUDIT": str(audit), "GTK_RUNTIME_AUDIT_LOG": str(log)}

        def execute(executable, args, child_env=env):
            log.unlink(missing_ok=True)
            result = subprocess.run([str(loader), "--inhibit-cache", str(executable), *map(str, args)],
                                    env=child_env, text=True, capture_output=True, timeout=60)
            loaded = check_loaded(log, objects, libc, {probe.resolve(), audit.resolve()})
            if result.returncode:
                raise Broken(f"native command failed ({result.returncode}): {executable} {args}\n"
                             f"{result.stdout}{result.stderr}")
            if result.stderr:
                # Module/data-path warnings are evidence, not a successful verdict.
                raise Broken(f"native command emitted warnings/errors: {result.stderr}")
            return result.stdout, loaded

        probe_env = {**env, "GSK_RENDERER": "cairo", "GTK_A11Y": "none",
                     "GTK_RUNTIME_EXPECT_ROOT": str(root)}
        stdout, loaded = execute(probe, [work / "pixels.png", *critical.values()], probe_env)
        if not set(critical.values()).issubset(loaded):
            raise Broken("native probe did not actually load all critical GTK runtime providers")
        # A real GIO module, not GLib's dummy backend, must have been loaded.
        # glib-networking names its modules libgioopenssl.so/libgiognutls.so;
        # the OpenSSL name contains no "tls" substring.
        if not any(p.name.startswith("libgio")
                   and any(backend in p.name for backend in ("tls", "openssl", "gnutls"))
                   for p in loaded):
            raise Broken("no runtime-owned GIO TLS module observed by the loader audit")
        print(stdout, end="")
        if consumer:
            executable = next((p for p in (consumer / "dbpp", consumer / "bin/dbpp") if p.is_file()), None)
            if executable is None or executable.resolve() not in objects:
                raise Broken(f"no real dbpp ELF executable in {consumer}")
            home = work / "consumer-home"
            home.mkdir()
            consumer_env = {**env, "HOME": str(home), "XDG_DATA_HOME": str(home / "data"),
                            "XDG_CONFIG_HOME": str(home / "config"), "DBPP_DATA_DIR": str(home / "dbpp-data")}

            def dbpp(*args):
                return execute(executable, list(args), consumer_env)[0]

            if not re.search(r"\b0\.4\.2\b", dbpp("--version")):
                raise Broken("consumer is not dbpp 0.4.2")
            info = json.loads(dbpp("doctor", "--json"))
            if not (info.get("ok") is True and info.get("version") == "0.4.2"
                    and info.get("sqlite_driver_exists") is True):
                raise Broken(f"dbpp doctor failed: {info}")
            database = home / "verify.sqlite"
            for sql in ("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT);",
                        "INSERT INTO items (name) VALUES ('xlings');"):
                if json.loads(dbpp("exec", "--sqlite", database, sql, "--json")).get("ok") is not True:
                    raise Broken(f"dbpp SQLite DDL/DML failed: {sql}")
            rows = json.loads(dbpp("query", "--sqlite", database, "SELECT id, name FROM items;", "--json"))
            if not (rows.get("ok") is True and rows.get("row_count") == 1 and rows.get("rows") == [["1", "xlings"]]):
                raise Broken(f"dbpp SQLite query failed: {rows}")
            print("PASS: real dbpp 0.4.2 version, doctor, SQLite DDL/insert/query")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--runtime-root", required=True, type=Path)
    parser.add_argument("--arch", required=True, choices=tuple(MACHINES))
    parser.add_argument("--libc-root", type=Path, help="explicit installed xim:glibc provider (required for acceptance)")
    parser.add_argument("--consumer-root", type=Path, help="installed and sealed real dbpp 0.4.2 payload")
    args = parser.parse_args(argv)
    try:
        if args.libc_root is None:
            raise Prerequisite("--libc-root must explicitly identify the installed xim:glibc provider")
        root, libc_root = args.runtime_root.resolve(), args.libc_root.resolve()
        consumer = args.consumer_root.resolve() if args.consumer_root else None
        if inside(root, libc_root) or inside(libc_root, root):
            raise Broken("runtime and glibc provider roots must be separate")
        objects = scan(root, args.arch)
        runtime_providers = providers(objects)
        if set(runtime_providers) & CRT:
            raise Broken("runtime bundles a second C runtime/loader instead of using xim:glibc")
        check_relocated(root)
        libc_objects = scan(libc_root, args.arch)
        libc = {name: path for name, path in providers(libc_objects).items() if name in CRT}
        critical = {}
        for name in CRITICAL:
            path = runtime_providers.get(name)
            if path is None:
                raise Broken(f"no actual runtime ELF provider for {name}")
            critical[name] = path
        roots = (root,)
        if consumer:
            if inside(consumer, root) or inside(root, consumer) or inside(consumer, libc_root):
                raise Broken("consumer must have a separate payload root")
            objects.update(scan(consumer, args.arch))
            roots += (consumer,)
        check_closure(objects, libc, roots)
        print(f"PASS: {len(objects)} ELF objects are {args.arch}, relocated, with a sealed private dependency closure")
        run_native(root, libc_root, args.arch, objects, libc, critical, consumer)
        print("PASS: complete native gtk4-runtime acceptance (no host library providers)")
        return 0
    except Prerequisite as exc:
        print(f"NOT RUN: {exc}", file=sys.stderr)
        return 3
    except (Broken, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
