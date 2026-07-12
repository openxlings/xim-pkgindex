"""Regression coverage for packages migrated to the current CI contract."""

from pathlib import Path

import pytest


ROOT = Path(__file__).parents[1]
PACKAGES = ("fish", "griddycode", "nvim", "pnpm")


@pytest.mark.static
@pytest.mark.parametrize("package", PACKAGES)
def test_package_uses_v2_and_ci_mirror_update(package):
    path = next((ROOT / "pkgs").glob(f"*/{package}.lua"))
    text = path.read_text(encoding="utf-8")

    assert 'spec = "2"' in text
    assert "ci = { mirror = true, update = true }" in text


@pytest.mark.static
@pytest.mark.parametrize("package", PACKAGES)
def test_package_keeps_update_source_contract(package):
    path = next((ROOT / "pkgs").glob(f"*/{package}.lua"))
    text = path.read_text(encoding="utf-8")

    assert ("url_template" in text or "source = {" in text)
    assert ("{version}" in text or "${version}" in text)
