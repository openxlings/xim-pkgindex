"""Runtime data inventory accepts owned tar links and rejects unavailable data."""
import importlib.util
from pathlib import Path
import io
import tarfile
import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('glibc_inventory', ROOT/'.agents/tools/check-glibc-data-inventory.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
pytestmark = pytest.mark.static


@pytest.mark.parametrize('link', ['hard', 'relative', 'missing', 'outside', 'cycle'])
def test_timezone_tar_link_resolves_to_owned_data(tmp_path, link):
    archive = tmp_path/'glibc.tar.gz'
    root = 'glibc-2.44.3-r3-linux-aarch64'
    with tarfile.open(archive, 'w:gz') as stream:
        for name in (*module.REQUIRED, 'lib/ld-linux-aarch64.so.1', 'lib/libc.so.6', 'share/zoneinfo/UTC'):
            if name == 'share/zoneinfo/Etc/UTC': continue
            item = tarfile.TarInfo(root+'/'+name)
            item.size = 8
            stream.addfile(item, io.BytesIO(b'fixture\n'))
        alias = tarfile.TarInfo(root+'/lib64'); alias.type=tarfile.SYMTYPE; alias.linkname='lib'; stream.addfile(alias)
        item = tarfile.TarInfo(root+'/share/zoneinfo/Etc/UTC')
        item.type = tarfile.LNKTYPE if link in ('hard','missing') else tarfile.SYMTYPE
        item.linkname = {'hard':root+'/share/zoneinfo/UTC', 'relative':'../UTC',
                         'missing':root+'/missing', 'outside':'/usr/share/zoneinfo/UTC',
                         'cycle':'UTC'}[link]
        stream.addfile(item)
    report = module.inspect(archive, 'aarch64', 3)
    assert report['status'] == ('passed' if link in ('hard','relative') else 'failed')
    assert ('share/zoneinfo/Etc/UTC' in report['missing']) == (link not in ('hard','relative'))
