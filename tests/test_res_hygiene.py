"""Exercise resource hygiene against real ELF bytes, not source-text assertions."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def checker(tmp_path_factory):
    if sys.platform != "linux":
        pytest.skip("ELF fixtures require Linux")
    for tool in ("bash", "cc", "file", "readelf"):
        if not shutil.which(tool):
            pytest.skip(f"ELF fixtures require {tool}")
    text = (ROOT / "tools/res/build.sh").read_text()
    start = text.index("check_elf_hygiene() {")
    function = text[start:text.index("\n}\n", start) + 3]
    script = tmp_path_factory.mktemp("res-hygiene") / "check.sh"
    script.write_text(
        'set -euo pipefail\n'
        'die() { printf "%s\\n" "$*" >&2; exit 1; }\n'
        + function + '\ncheck_elf_hygiene "$@"\n'
    )
    return script


@pytest.fixture
def elf(tmp_path, checker):
    def build(runtime_path="/opt/runtime", flags=()):
        binary = tmp_path / "app"
        source = (
            '#include <stdio.h>\n'
            f'int main(void) {{ return puts({json.dumps(runtime_path)}) < 0; }}\n'
        )
        subprocess.run(
            ["cc", "-x", "c", "-g0", *flags, "-o", str(binary), "-"],
            input=source, text=True, capture_output=True, check=True, timeout=10,
        )
        return binary
    return build


def scan(checker, directory, strict=False):
    return subprocess.run(
        ["bash", str(checker), *(["--strict-tmp"] if strict else []), str(directory)],
        text=True, capture_output=True, timeout=10,
    )


@pytest.mark.parametrize("runtime_path", ["/home/%s", "/Users/%s", "/home/alice/documents"])
@pytest.mark.parametrize("strict", [False, True])
def test_runtime_home_defaults_are_not_build_paths(checker, elf, runtime_path, strict):
    binary = elf(runtime_path)
    result = scan(checker, binary.parent, strict)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize("build_path", [
    "/w/src/main.c",
    "/home/runner/work/pkg/main.c",
    "/Users/runner/work/pkg/main.c",
    "/tmp/ccXYZ/source.c",
])
def test_concrete_build_prefixes_are_rejected(checker, elf, build_path):
    binary = elf(build_path)
    result = scan(checker, binary.parent)
    assert result.returncode != 0, result.stdout


@pytest.mark.parametrize("flags", [
    ("-Wl,-rpath,/opt/runtime",),
    ("-Wl,--disable-new-dtags,-rpath,/opt/runtime",),
])
def test_dynamic_search_paths_are_rejected(checker, elf, flags):
    binary = elf(flags=flags)
    result = scan(checker, binary.parent)
    assert result.returncode != 0, result.stdout


def test_dwarf_sections_are_rejected(checker, elf):
    binary = elf(flags=("-g",))
    result = scan(checker, binary.parent)
    assert result.returncode != 0, result.stdout


def test_truncated_elf_is_not_silently_accepted(checker, elf):
    binary = elf()
    binary.write_bytes(binary.read_bytes()[:64])
    result = scan(checker, binary.parent)
    assert result.returncode != 0, result.stdout


def test_strict_tmp_checks_non_elf_payload_files(checker, elf):
    binary = elf()
    (binary.parent / "runtime.pc").write_text("prefix=/tmp/runtime-prefix\n")
    normal = scan(checker, binary.parent)
    assert normal.returncode == 0, normal.stderr
    strict = scan(checker, binary.parent, strict=True)
    assert strict.returncode != 0, strict.stdout
