"""The index client floor covers architecture-dependent catalog metadata."""
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tools/check_index_compat.py"
pytestmark = pytest.mark.static


@pytest.mark.parametrize("floor,expected", [
    ("2026.10.4.1", 1), ("2026.10.8.1", 0), ("2026.10.8.2", 0),
])
def test_catalog_architecture_requires_new_loader(tmp_path, floor, expected):
    (tmp_path / "pkgs").mkdir()
    (tmp_path / "pkgs/glibc.lua").write_text(
        'local recipe_arch = (os.arch and os.arch()) or "x86_64"\n'
        'package = { name = "glibc" }\n')
    (tmp_path / "index-compat.json").write_text(json.dumps({
        "requires": {"xlings": {"min": floor}},
    }))
    result = subprocess.run([sys.executable, str(CHECKER), str(tmp_path)],
                            text=True, capture_output=True)
    assert result.returncode == expected, result.stdout + result.stderr
    assert "process architecture in catalog metadata" in result.stdout


def test_comments_do_not_raise_catalog_arch_floor(tmp_path):
    (tmp_path / "pkgs").mkdir()
    (tmp_path / "pkgs/example.lua").write_text(
        '-- local recipe_arch = (os.arch and os.arch()) or "x86_64"\n'
        'package = { name = "example" }\n')
    result = subprocess.run([sys.executable, str(CHECKER), str(tmp_path)],
                            text=True, capture_output=True)
    assert result.returncode == 0
    assert "no version-gated construct found" in result.stdout
