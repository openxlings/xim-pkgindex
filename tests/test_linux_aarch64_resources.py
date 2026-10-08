"""Native routes match admitted assets and do not expose older foreign payloads."""
import json
from pathlib import Path
import shutil
import subprocess
import pytest

ROOT = Path(__file__).resolve().parent.parent
REPORT = json.loads((ROOT / '.agents/docs/2026-10-08-llvm-2313-aarch64-resource-admission.json').read_text())
pytestmark = pytest.mark.static

ROUTES = [
    ('l/llvm', '23.1.3', 'llvm-23.1.3'),
    ('l/llvm-tools', '23.1.3', 'llvm-tools-23.1.3'),
    ('g/glibc', '2.44.3', 'glibc-2.44.3-r2'),
    ('g/gcc-runtime', '15.1.0', 'gcc-runtime-15.1.0'),
    ('l/linux-headers', '5.11.1', 'linux-headers-5.11.1'),
    ('z/zlib', '1.3.1', 'zlib-1.3.1'),
    ('l/libxml2', '2.13.5', 'libxml2-2.13.5'),
    ('l/libxml2', '2.13.5-1', 'libxml2-2.13.5'),
]


@pytest.mark.parametrize('recipe,version,stem', ROUTES)
def test_routes_use_real_admitted_native_assets(recipe, version, stem):
    name = f'{stem}-linux-aarch64.tar.gz'
    lua = shutil.which('lua5.4') or shutil.which('lua')
    source = '''
function import() end
os.arch = function() return "aarch64" end
os.host = function() return "linux" end
assert(loadfile(arg[1]))()
local seen = false
for _, arch in ipairs(package.archs) do if arch == "aarch64" then seen = true end end
assert(seen, "native architecture missing")
local e = assert(package.xpm.linux[arg[2]].aarch64)
print(e.url.GLOBAL)
print(e.url.CN)
print(e.sha256)
'''
    result = subprocess.run([lua, '-', str(ROOT/f'pkgs/{recipe}.lua'), version], input=source, text=True, capture_output=True, check=True)
    global_url, cn_url, digest = result.stdout.splitlines()
    report = REPORT
    if recipe == 'g/glibc':
        report = json.loads((ROOT / '.agents/docs/2026-10-08-glibc-r2-data-inventory.json').read_text())
    published = next(a for a in report['global_api_resources'] if a['archive'] == name)
    assert global_url == published['url']
    assert cn_url == global_url.replace('https://github.com/', 'https://gitcode.com/')
    assert digest == report['archives'][name] == published['sha256']


@pytest.mark.parametrize('recipe,versions', [
    ('l/llvm', ['20.1.7', '22.1.8']),
    ('l/llvm-tools', ['20.1.7', '22.1.8']),
    ('g/glibc', ['2.39', '2.44', '2.44.2']),
])
def test_older_versions_cannot_fall_through_to_x86_payloads(recipe, versions):
    lua = shutil.which('lua5.4') or shutil.which('lua')
    source = '''
function import() end
os.arch = function() return "aarch64" end
os.host = function() return "linux" end
assert(loadfile(arg[1]))()
for i = 2, #arg do
 local e = package.xpm.linux[arg[i]]
 assert(e == nil or (e.x86_64 and not e.aarch64 and not e.url and not e.sha256), arg[i])
end
'''
    subprocess.run([lua, '-', str(ROOT/f'pkgs/{recipe}.lua'), *versions], input=source, text=True, capture_output=True, check=True)
