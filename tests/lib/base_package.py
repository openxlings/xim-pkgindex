"""The layout contract of an mcpp base package: a sysroot whose root carries `mcpp.toml`.

A base package is admitted by what a build reads from it, not by its digest.
These checks read the installed tree alone -- no compiler, no engine -- and
state the part of the admission contract that the tree answers by itself:

    the manifest parses and names files that exist;
    a package that provides the C++ layer names the std module's source;
    every symbolic link a build reads (a library, an object, a header)
    resolves inside the tree;
    every GNU ld script of the tree names paths that exist under the root,
    read sysroot-relative, and none carries an install-time placeholder.

Each of these was a defect of a published revision that the digest and the
install both passed (aarch64-linux-gnu-sysroot 2.44.3 revision 2). What a
build and a run decide -- that a C program, a C++ program and `import std`
link and start -- is the admission job's, which needs the engine.
"""
import os
import re
import tomllib

BUILD_FILES = ("std-module", "std-compat-module")
BUILD_DIRS = ("compiler_runtime_dir",)
SCRIPT_PATH = re.compile(rb"(?<![\w.+-])(/[^\s()]+)")


def manifest(root):
    path = os.path.join(root, "mcpp.toml")
    assert os.path.isfile(path), "a base package carries mcpp.toml at its root"
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def provided(doc):
    out = {}
    for word in doc.get("package", {}).get("provides", []):
        if word.startswith("mcpp:") and "=" in word:
            layer, impl = word[len("mcpp:"):].split("=", 1)
            out[layer] = impl
    return out


def assert_manifest_names_what_exists(root):
    doc = manifest(root)
    layers = provided(doc)
    assert "c-abi" in layers, "a base package provides the C library layer (mcpp:c-abi=<impl>)"
    build = doc.get("build", {})
    package = doc.get("package", {})
    for key in BUILD_FILES:
        value = build.get(key, package.get(key))
        if value is not None:
            assert os.path.isfile(os.path.join(root, value)), f"{key} names {value}, which is not a file"
    for key in BUILD_DIRS:
        if key in build:
            assert os.path.isdir(os.path.join(root, build[key])), f"{key} names {build[key]}, which is not a directory"
    for directory in build.get("include_dirs", []):
        assert os.path.isdir(os.path.join(root, directory)), f"include_dirs names {directory}, which is not a directory"
    if "c++-abi" in layers:
        assert build.get("std-module", package.get("std-module")), \
            "a package that provides mcpp:c++-abi names the std module's source (std-module)"
    return doc


def build_reads(name):
    """Whether a build reads a file of this name: a library, an object, a header, a module source."""
    return (name.endswith((".a", ".o", ".h", ".hpp", ".cppm")) or ".so" in name
            or (name.startswith("lib") and "." in name))


def assert_links_resolve_inside(root):
    """A link a build reads resolves, and inside the package. Other links are the
    upstream tree's own (a system's base carries links into parts it does not ship)."""
    real_root = os.path.realpath(root)
    for directory, _, names in os.walk(root):
        for name in names:
            path = os.path.join(directory, name)
            if not os.path.islink(path) or not build_reads(name):
                continue
            target = os.path.realpath(path)
            assert os.path.exists(target), f"{os.path.relpath(path, root)} links to nothing"
            assert target == real_root or target.startswith(real_root + os.sep), \
                f"{os.path.relpath(path, root)} links outside the package"


def ld_scripts(root):
    for directory, _, names in os.walk(root):
        for name in names:
            path = os.path.join(directory, name)
            if os.path.islink(path) or not os.path.isfile(path) or os.path.getsize(path) > 4096:
                continue
            if not (name.endswith(".a") or ".so" in name):
                continue
            with open(path, "rb") as handle:
                data = handle.read()
            if data.startswith(b"/* GNU ld script") or b"GROUP (" in data or data.startswith(b"INPUT("):
                yield path, data


def assert_ld_scripts_are_sysroot_relative(root):
    for path, data in ld_scripts(root):
        rel = os.path.relpath(path, root)
        assert b"/nonexistent/" not in data, f"{rel} carries an install-time placeholder"
        body = re.sub(rb"/\*.*?\*/", b"", data, flags=re.S)
        for match in SCRIPT_PATH.findall(body):
            named = match.decode()
            assert os.path.exists(os.path.join(root, named.lstrip("/"))), \
                f"{rel} names {named}, which is not in the package"


def assert_base_package(root):
    doc = assert_manifest_names_what_exists(root)
    assert_links_resolve_inside(root)
    assert_ld_scripts_are_sysroot_relative(root)
    return doc
