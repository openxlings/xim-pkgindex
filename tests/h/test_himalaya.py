"""Himalaya's portable payload and real, account-free local Maildir behavior."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "himalaya"
VERSION = "3.0.0"
PKG_FILE = "pkgs/h/himalaya.lua"
ROOT = Path(__file__).resolve().parents[2]
SUBJECT = "Xlings offline Maildir fixture"
BODY = "Offline body: café verified without a server."
MESSAGE = (
    "From: Offline Sender <sender@example.invalid>\r\n"
    "To: reader@example.invalid\r\n"
    f"Subject: {SUBJECT}\r\n"
    "Date: Tue, 14 Nov 2023 22:13:20 +0000\r\n"
    "Message-ID: <xlings-offline@example.invalid>\r\n"
    "MIME-Version: 1.0\r\n"
    "Content-Type: text/plain; charset=utf-8\r\n"
    "Content-Transfer-Encoding: quoted-printable\r\n"
    "\r\n"
    "Offline body: caf=C3=A9 verified without a server.\r\n"
).encode("ascii")


def _xlings(*args):
    # Native direct invocation also works on Windows; bash -l may select WSL.
    exe = Path(xlings_home()) / "bin" / ("xlings.exe" if os.name == "nt" else "xlings")
    if not exe.is_file():
        found = shutil.which("xlings")
        assert found, "native xlings is required for lifecycle tests"
        exe = Path(found)
    result = subprocess.run(
        [str(exe), "-y", *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=240,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert not re.search(r"\[error\].*failed", result.stdout + result.stderr, re.I)
    return result.stdout


def _shim():
    home = Path(xlings_home())
    subos = home / "subos"
    names = [os.environ.get("XLINGS_TEST_SUBOS", "current"), "default"]
    for name in names:
        binary = subos / name / "bin" / ("himalaya.exe" if os.name == "nt" else "himalaya")
        if binary.is_file():
            return binary
    pytest.fail(f"himalaya shim is missing from {subos}")


def check_offline_maildir(binary, root):
    """Use only one explicit local backend; no auth, remote or send configuration."""
    root = Path(root)
    mailbox = root / "mail" / "INBOX"
    for directory in ("cur", "new", "tmp"):
        (mailbox / directory).mkdir(parents=True)
    # A new/ filename is portable to Windows (cur/'s :2, flags are not).
    message = mailbox / "new" / "1700000000.M1P1.xlings"
    message.write_bytes(MESSAGE)
    config = root / "offline.toml"
    config.write_text(
        '[accounts.offline]\n'
        'default = true\n'
        'email = "reader@example.invalid"\n'
        f'maildir.root = {json.dumps((root / "mail").as_posix())}\n'
        'maildir.layout = "fs"\n'
        'mailbox.alias.inbox = "INBOX"\n'
        'message.send.save-copy = false\n',
        encoding="utf-8",
    )
    env = os.environ.copy()
    for variable, directory in (
        ("HOME", "home"), ("USERPROFILE", "home"),
        ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
        ("XDG_CACHE_HOME", "cache"), ("APPDATA", "config"),
        ("LOCALAPPDATA", "data"),
    ):
        path = root / directory
        path.mkdir(exist_ok=True)
        env[variable] = str(path)
    env["XLINGS_HOME"] = xlings_home()
    command = [str(binary), "--config", str(config), "--account", "offline",
               "--backend", "maildir", "--json", "--log-level", "off"]

    def run(*args):
        result = subprocess.run(
            [*command, *args], env=env, capture_output=True,
            text=True, encoding="utf-8", timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return json.loads(result.stdout)

    folders = run("mailbox", "list")
    assert folders["errors"] == []
    assert any(folder["name"] == "INBOX" and folder["role"] == "inbox"
               for folder in folders["mailboxes"])
    listing = run("envelope", "list", "--mailbox", "INBOX")
    assert listing["errors"] == []
    assert listing["total"] == 1
    envelope, = listing["envelopes"]
    assert envelope["subject"] == SUBJECT
    assert envelope["from"] == [{"name": "Offline Sender", "email": "sender@example.invalid"}]
    assert envelope["messageId"] == "xlings-offline@example.invalid"
    decoded = run("message", "read", "--mailbox", "INBOX", envelope["id"])
    assert decoded["headers"]["subject"] == SUBJECT
    assert decoded["headers"]["from"] == envelope["from"]
    assert decoded["text"].strip() == BODY
    assert decoded["parts"][0]["mime"] == "text/plain"
    # Reading without --seen must not rewrite the source mail or its flags.
    assert message.read_bytes() == MESSAGE
    assert list((mailbox / "cur").iterdir()) == []
    assert config.read_text(encoding="utf-8").count("[accounts.") == 1
    assert not list((root / "config").rglob("*")), "must not create default account config"


@pytest.mark.static
@pytest.mark.parametrize("check", [
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_config_registers_package_name, assert_valid_xvm_node_kinds,
])
def test_metadata(check):
    check(parse_xpkg(PKG_FILE))


@pytest.mark.static
def test_program_and_supported_platforms():
    meta = parse_xpkg(PKG_FILE)
    assert meta.name == PKG and meta.spec == "2"
    assert meta.programs == [PKG]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}
    assert meta.has_installed and meta.has_install and meta.has_config and meta.has_uninstall
    assert_no_typos(PKG_FILE)


@pytest.mark.isolation
@pytest.mark.parametrize("check", [
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
])
def test_isolation(check):
    check(PKG_FILE)


@pytest.mark.isolation
def test_portable_runtime_boundary():
    meta = parse_xpkg(PKG_FILE)
    assert all(name.startswith("xim.libxpkg.") or name in {
        "xim.pkgindex.payload", "xim.pkgindex.shell",
    } for name in meta.imports)
    assert not re.search(r"\b(?:path\.|os\.(?:host|arch|curdir|exists)\(|raise\(|is_host\()",
                         meta.raw_content)


@pytest.mark.index
def test_index_registration():
    _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
    output = _xlings("search", PKG)
    assert PKG in output


@pytest.mark.lifecycle
def test_install():
    _xlings("install", under_test(PKG, VERSION))
    assert _shim().is_file()


@pytest.mark.verify
def test_version():
    result = subprocess.run([str(_shim()), "--version"], capture_output=True,
                            text=True, encoding="utf-8", timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert f"himalaya v{VERSION}" in result.stdout
    assert "+maildir" in result.stdout


@pytest.mark.verify
def test_offline_maildir(tmp_path):
    check_offline_maildir(_shim(), tmp_path)
