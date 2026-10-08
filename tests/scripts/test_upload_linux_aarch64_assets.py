"""The manual uploader rejects incomplete admission and immutable replacements."""
import hashlib
import importlib.util
import json
from pathlib import Path
import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_upload', ROOT / '.agents/tools/upload-linux-aarch64-assets.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def admitted(tmp_path):
    archives = {}
    for stem in module.ROUTES:
        extensions = ['tar.gz', 'tar.xz'] if stem.startswith('llvm-') else ['tar.gz']
        for extension in extensions:
            name = f'{stem}-linux-aarch64.{extension}'
            data = name.encode()
            (tmp_path / name).write_bytes(data)
            digest = hashlib.sha256(data).hexdigest()
            (tmp_path / f'{name}.sha256').write_text(f'{digest}  {name}\n')
            archives[name] = digest
    report = {'status': 'passed', 'architecture': 'aarch64', 'commit': 'reviewed',
              'gates': ['managed-process-libraries', 'default-timezone-locale-gconv-host-nss-policy',
                        'managed-uapi-crt', 'host-header-negative', 'std-and-std.compat', 'cxx-compile-link-run'],
              'archives': archives}
    (tmp_path / 'BUILD-ADMISSION.json').write_text(json.dumps(report))
    return report


def test_admitted_routes_preserve_all_compression_formats(tmp_path):
    admitted(tmp_path)
    records = module.validate(tmp_path, 'reviewed')
    assert len(records) == 9
    assert {item[2] for item in records} == {'llvm', 'glibc', 'gcc-runtime', 'linux-headers', 'zlib', 'libxml2'}


@pytest.mark.parametrize('change', ['failed', 'missing_gate', 'wrong_commit', 'changed_bytes', 'changed_sidecar'])
def test_upload_requires_matching_complete_admission(tmp_path, change):
    report = admitted(tmp_path)
    if change == 'failed': report['status'] = 'failed'
    elif change == 'missing_gate': report['gates'].remove('managed-process-libraries')
    elif change == 'wrong_commit': report['commit'] = 'other'
    elif change == 'changed_bytes': (tmp_path / 'zlib-1.3.1-linux-aarch64.tar.gz').write_bytes(b'replaced')
    elif change == 'changed_sidecar': (tmp_path / 'zlib-1.3.1-linux-aarch64.tar.gz.sha256').write_text('fake zlib.tar.gz')
    (tmp_path / 'BUILD-ADMISSION.json').write_text(json.dumps(report))
    with pytest.raises(ValueError): module.validate(tmp_path, 'reviewed')


def test_remote_identity_rejects_replacing_immutable_asset(tmp_path, monkeypatch):
    file = tmp_path / 'asset.tar.gz'; file.write_bytes(b'new')
    release = {'assets': [{'id': 7, 'name': file.name, 'digest': 'sha256:other'}]}
    monkeypatch.setattr(module.subprocess, 'check_output', lambda *args, **kwargs: b'old')
    with pytest.raises(ValueError, match='immutable remote asset differs'):
        module.ensure_immutable(file, 'xlings-res/package', release)


def test_remote_identical_asset_is_a_noop(tmp_path, monkeypatch):
    file = tmp_path / 'asset.tar.gz'; file.write_bytes(b'same')
    digest = hashlib.sha256(b'same').hexdigest()
    release = {'assets': [{'id': 7, 'name': file.name, 'digest': f'sha256:{digest}'}]}
    def forbidden(*args, **kwargs): raise AssertionError('server digest should avoid downloading identical bytes')
    monkeypatch.setattr(module.subprocess, 'check_output', forbidden)
    assert module.ensure_immutable(file, 'xlings-res/package', release)


@pytest.mark.parametrize('change', ['pending', 'failed', 'other_repository', 'fork_head', 'other_workflow', 'invalid_sha'])
def test_reuse_rejects_untrusted_or_incomplete_source_run(change):
    reuse_spec = importlib.util.spec_from_file_location('native_reuse', ROOT / '.agents/tools/reuse-linux-aarch64-assets.py')
    reuse = importlib.util.module_from_spec(reuse_spec)
    reuse_spec.loader.exec_module(reuse)
    run = {'status': 'completed', 'conclusion': 'success',
           'repository': {'full_name': 'openxlings/xim-pkgindex'},
           'head_repository': {'full_name': 'openxlings/xim-pkgindex'},
           'path': '.github/workflows/llvm-linux-aarch64.yml', 'head_sha': 'a'*40}
    if change == 'pending': run['status'] = 'in_progress'
    elif change == 'failed': run['conclusion'] = 'failure'
    elif change == 'other_repository': run['repository']['full_name'] = 'other/project'
    elif change == 'fork_head': run['head_repository']['full_name'] = 'fork/project'
    elif change == 'other_workflow': run['path'] = '.github/workflows/other.yml'
    elif change == 'invalid_sha': run['head_sha'] = 'bad'
    with pytest.raises(ValueError): reuse.validate(run, 'openxlings/xim-pkgindex')


@pytest.mark.parametrize('change', ['none', 'corrupt', 'additional', 'missing'])
def test_published_glibc_reuse_preserves_exact_other_archive_identities(tmp_path, monkeypatch, change):
    spec = importlib.util.spec_from_file_location('native_reuse_exact', ROOT / '.agents/tools/reuse-linux-aarch64-assets.py')
    reuse = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reuse)
    # Fixture bytes replace only test expectations. Production SHA constants
    # remain the identities of the admitted native source closure.
    expected = {}
    for name in reuse.UNCHANGED_ARCHIVES:
        content = ('owned fixture ' + name).encode()
        (tmp_path / name).write_bytes(content)
        expected[name] = hashlib.sha256(content).hexdigest()
    (tmp_path / 'glibc-2.44.3-r1-linux-aarch64.tar.gz').write_bytes(b'old glibc fixture')
    monkeypatch.setattr(reuse, 'UNCHANGED_ARCHIVES', expected)
    selected = next(iter(expected))
    if change == 'corrupt': (tmp_path / selected).write_bytes(b'corrupt')
    elif change == 'additional': (tmp_path / 'unexpected.tar.gz').write_bytes(b'foreign')
    elif change == 'missing': (tmp_path / selected).unlink()
    if change == 'none': reuse.verify_unchanged_archives(tmp_path)
    else:
        with pytest.raises(ValueError): reuse.verify_unchanged_archives(tmp_path)
