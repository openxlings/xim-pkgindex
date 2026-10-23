"""Expired Actions transport must not change native source identities."""
import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_recovery', ROOT / '.agents/tools/reuse-linux-aarch64-assets.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


@pytest.mark.parametrize('corrupt', [False, True])
def test_recovery_checks_pinned_bytes_and_records_transport(tmp_path, monkeypatch, corrupt):
    data = b'immutable admitted archive'
    digest = hashlib.sha256(data).hexdigest()
    name = 'llvm-23.1.3-linux-aarch64.tar.gz'
    monkeypatch.setattr(mod, 'UNCHANGED_ARCHIVES', {name: digest})
    calls = []
    def run(command, **kwargs):
        calls.append(command)
        Path(command[command.index('-o') + 1]).write_bytes(b'changed bytes' if corrupt else data)
    monkeypatch.setattr(mod.subprocess, 'run', run)
    if corrupt:
        with pytest.raises(ValueError, match='differs'):
            mod.recover_published_archives(tmp_path, '123', 'a' * 40)
        assert not (tmp_path / 'PUBLISHED-ARCHIVE-REUSE.json').exists()
    else:
        mod.recover_published_archives(tmp_path, '123', 'a' * 40)
        proof = json.loads((tmp_path / 'PUBLISHED-ARCHIVE-REUSE.json').read_text())
        assert proof['source_commit'] == 'a' * 40
        assert proof['archives'][0]['sha256'] == digest
        assert 'fresh native gates' in proof['admission']
        assert calls[0][-1] == 'https://github.com/xlings-res/llvm/releases/download/23.1.3/' + name


def test_recovery_never_guesses_unknown_coordinates(tmp_path, monkeypatch):
    monkeypatch.setattr(mod, 'UNCHANGED_ARCHIVES', {'unknown.tar.gz': 'a' * 64})
    with pytest.raises(ValueError, match='unrecognized'):
        mod.recover_published_archives(tmp_path, '123', 'a' * 40)


@pytest.mark.parametrize('change', ['none', 'digest', 'source', 'revision'])
def test_published_r4_stays_bound_to_reviewed_native_r3(change):
    import copy
    proof = json.loads((ROOT / '.agents/docs/2026-10-08-glibc-r3-resource-admission.json').read_text())
    ledger = json.loads((ROOT / '.agents/docs/2026-10-08-glibc-r3-source-build.json').read_text())
    derived = copy.deepcopy(json.loads((ROOT / '.agents/docs/2026-10-10-glibc-r4-resource-admission.json').read_text()))
    name = 'glibc-2.44.3-r4-linux-aarch64.tar.gz'
    digest = derived['archives'][name]
    revision = '4'
    if change == 'digest': digest = '0' * 64
    elif change == 'source': derived['derived_from']['archives']['glibc-2.44.3-r3-linux-aarch64.tar.gz'] = '0' * 64
    elif change == 'revision': revision = '5'
    if change == 'none':
        mod.validate_glibc_derivation(revision, name, digest, proof, ledger, derived)
    else:
        with pytest.raises(ValueError, match='derivation'):
            mod.validate_glibc_derivation(revision, name, digest, proof, ledger, derived)
