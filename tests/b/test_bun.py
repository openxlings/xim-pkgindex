"""Tests for the native Bun release package."""
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_no_direct_pkg_manager,
    assert_uses_new_api, assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "bun"
PKG_FILE = "pkgs/b/bun.lua"
VERSION = "1.4.5"
PREVIOUS_VERSION = "1.3.11"

UPSTREAM = {
    "linux": {
        "x86_64": "dcb23a18a1c2fff12d57bcef696dbbb42eb67fde29f43816ecb595459a24c463",
        "aarch64": "18656a3bf0ea5641f5796ae4213b75255579a70a0fded2f337933785568cdf84",
    },
    "macosx": {
        "x86_64": "fb0121739a7e80e7511b6bfe4d2116422b48ba18a013acadef0c425348e95891",
        "aarch64": "b5d6bc2e13caf14e57c89661e89efd073ff16165b41bfe43882616410609cd10",
    },
    "windows": {
        "x86_64": "3c081c73865e7a3453a9d514cc2ba3d699880621bcf67bb17241ff5194cb1d4b",
        "aarch64": "41f57d49c3c6811888d9633c569e40b4eb1f7e92b5e5336e3abd3af03187d77a",
    },
}
ASSET_URLS = {
    "linux": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-linux-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-linux-aarch64.zip",
    },
    "macosx": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-darwin-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-darwin-aarch64.zip",
    },
    "windows": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-windows-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-windows-aarch64.zip",
    },
}
AUTUPDATE_URLS = {
    "linux": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-aarch64.zip",
    },
    "macosx": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-aarch64.zip",
    },
    "windows": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-aarch64.zip",
    },
}


def _assert_bun_output(cmd, contains):
    try:
        assert_command_output(cmd, contains=contains)
    except AssertionError as error:
        arm_asset_url = ASSET_URLS["linux"]["aarch64"]
        script = rf'''set +e
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo "bun command: $(command -v bun)"
type -a bun
home="${{XLINGS_HOME:-$HOME/.xlings}}"
candidate="$(find "$home/data/xpkgs" -type f -path "*/{VERSION}/bun" -print -quit)"
echo "candidate executable: $candidate"
if [ -n "$candidate" ]; then
  runtime_loader="$home/abi/linux-aarch64-glibc/ld-linux-aarch64.so.1"
  host_loader="/lib/ld-linux-aarch64.so.1"
  file "$candidate"
  readelf -lW "$candidate" | grep -E 'interpreter|Requesting program interpreter'
  readelf -dW "$candidate" | grep -E 'NEEDED|RPATH|RUNPATH'
  file "$runtime_loader" "$host_loader"
  "$runtime_loader" --version; echo "xlings_loader_exit=$?"
  "$host_loader" --version; echo "host_loader_exit=$?"
  ldd "$candidate"
  "$candidate" --version; echo "inherited_env_exit=$?"
  env -u LD_LIBRARY_PATH "$candidate" --version; echo "clean_env_exit=$?"
  host_copy="$(mktemp -d)/bun"
  cp "$candidate" "$host_copy"
  patchelf --set-interpreter "$host_loader" --remove-rpath "$host_copy"
  env -u LD_LIBRARY_PATH "$host_copy" --version; echo "host_runtime_exit=$?"
fi
if [ "$(uname -m)" = "aarch64" ]; then
  original="/tmp/bun-1.4.5-linux-aarch64-original"
  archive="/tmp/bun-1.4.5-linux-aarch64-original.zip"
  if [ ! -s "$original" ]; then
    curl -fsSL "{arm_asset_url}" -o "$archive"
    unzip -p "$archive" bun > "$original"
    chmod +x "$original"
  fi
  sha256sum "$archive"
  file "$original"
  env -u LD_LIBRARY_PATH "$original" --version; echo "upstream_unpatched_exit=$?"
fi
bun --version; echo "shim_inherited_env_exit=$?"
env -u LD_LIBRARY_PATH bun --version; echo "shim_clean_env_exit=$?"
'''
        diagnostics = subprocess.run(
            ["bash", "-l", "-c", script],
            capture_output=True, text=True, timeout=30,
        )
        pytest.fail(
            f"{error}\nBun runtime diagnostics:\n"
            f"{diagnostics.stdout}{diagnostics.stderr}",
            pytrace=False,
        )


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def _platform_section(content, platform):
    xpm = content.split("xpm = {", 1)[1]
    platforms = ("linux", "macosx", "windows")
    start = xpm.index(f"        {platform} = {{")
    later = [xpm.index(f"        {name} = {{") for name in platforms
             if name != platform and xpm.find(f"        {name} = {{") > start]
    end = min(later) if later else xpm.index("\n    }\n}", start)
    return xpm[start:end]


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_official_release_matrix_and_checksums(self, meta):
        assert set(meta.platforms) == set(UPSTREAM)
        assert "x86_64" in meta.raw_content and "aarch64" in meta.raw_content

        for platform, expected in UPSTREAM.items():
            section = _platform_section(meta.raw_content, platform)
            assert f'["latest"] = {{ref = "{VERSION}"}}' in section
            assert f'["{VERSION}"] = {{' in section
            previous = re.search(
                rf'\["{PREVIOUS_VERSION}"\]\s*=\s*\{{\s*ref\s*=\s*"{PREVIOUS_VERSION}"\s*\}}',
                section,
            )
            assert previous, f"published {PREVIOUS_VERSION} entry changed for {platform}"

            version_start = section.index(f'["{VERSION}"] = {{')
            previous_start = section.index(f'["{PREVIOUS_VERSION}"] = {{', version_start)
            version_entry = section[version_start:previous_start]
            for arch, digest in expected.items():
                arch_entry = re.search(
                    rf"(?ms)^\s+{arch}\s*=\s*\{{(.*?)^\s+\}}", version_entry
                )
                assert arch_entry, f"missing {VERSION} resource for {platform}/{arch}"
                resource = arch_entry.group(1)
                assert re.search(
                    rf'url\s*=\s*"{re.escape(ASSET_URLS[platform][arch])}"', resource
                )
                hash_value = re.search(r'sha256\s*=\s*"([^"]+)"', resource)
                assert hash_value and hash_value.group(1) == digest
                assert re.fullmatch(r"[0-9a-f]{64}", digest)

    @pytest.mark.static
    def test_latest_install_uses_native_release_and_preserves_legacy_path(self, meta):
        content = meta.raw_content
        assert "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/" in content
        assert 'if version == "1.3.11" then' in content
        assert 'npm install --prefix' in content
        assert 'local extracted = pkginfo.install_file():replace(".zip", "")' in content
        assert 'pkginfo.version() == "1.3.11"' in content
        assert '"xim:node"' in content

    @pytest.mark.static
    def test_autoupdate_tracks_all_release_assets(self, meta):
        content = meta.raw_content
        extension = content.split("autoupdate = {", 1)[1].split("    xpm = {", 1)[0]
        assert 'source = "https://github.com/oven-sh/bun/releases"' in extension
        assert 'tag = "bun-v${version}"' in extension
        assert "GLOBAL = {" in extension and "required = true" in extension
        assert "CN =" not in extension

        for platform, assets in AUTUPDATE_URLS.items():
            assert re.search(rf"(?m)^\s+{platform}\s*=\s*\{{", extension)
            for arch, url in assets.items():
                assert re.search(
                    rf'(?m)^\s+{arch}\s*=\s*"{re.escape(url)}",?\r?$', extension
                ), f"missing autoupdate URL for {platform}/{arch}"


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_host_package_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG, VERSION), timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_bun_version(self):
        _assert_bun_output("bun --version", contains=VERSION)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_bun_runs_javascript(self):
        _assert_bun_output("bun -e 'console.log(6 * 7)'", contains="42")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("bun")
