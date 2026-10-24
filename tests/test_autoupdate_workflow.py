"""The production workflow uses the tested batched scanner without polluting its cursor."""
from pathlib import Path

import pytest
import yaml

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]


def load(name):
    return yaml.safe_load((ROOT / '.github/workflows' / name).read_text())


def test_scan_and_proposal_limits_are_independent():
    policy = yaml.safe_load((ROOT / '.github/xpkgindex-update.yml').read_text())
    assert policy['max_packages'] == 50
    assert policy['max_prs'] == 20
    flow = load('xpkgindex-update.yml')
    inputs = flow.get('on', flow.get(True))['workflow_dispatch']['inputs']
    assert inputs['max_batches']['default'] == 20
    scan = flow['jobs']['scan']
    step = next(s for s in scan['steps'] if s.get('id') == 'check')
    assert '--max-batches "$MAX_BATCHES"' in step['run']
    assert '--state-file .update-state.json' in step['run']


def test_manual_dry_run_does_not_propose_or_change_production_cursor():
    flow = load('xpkgindex-update.yml')
    assert '!inputs.dry_run' in flow['jobs']['propose']['if']
    assert 'github.event.repository.default_branch' in flow['jobs']['propose']['if']
    assert "needs.scan.outputs.checked == 'success'" in flow['jobs']['propose']['if']
    cache = [s for s in flow['jobs']['scan']['steps'] if s.get('uses', '').startswith('actions/cache/')]
    assert len(cache) == 2
    for step in cache:
        assert '!inputs.dry_run' in step['if']
        assert "inputs.package == ''" in step['if']
        assert 'github.event.repository.default_branch' in step['if']


def test_discovery_errors_still_fail_the_final_gate():
    flow = load('xpkgindex-update.yml')
    gate = flow['jobs']['result']
    assert 'always()' in gate['if']
    assert '"$CHECK" != failure' in gate['steps'][0]['run']
    assert '"$SCAN" == success' in gate['steps'][0]['run']


def test_all_workflows_use_the_same_updater_revision():
    candidate, discovery, entry = [load(n) for n in ('ci-candidates.yml', 'xpkgindex-update.yml', 'ci.yml')]
    revision = candidate['env']['UPDATER_COMMIT']
    assert discovery['env']['UPDATER_COMMIT'] == revision
    checkout = next(s for s in entry['jobs']['plan']['steps'] if s.get('with', {}).get('repository') == 'openxlings/xpkgindex-update')
    assert checkout['with']['ref'] == revision


def test_candidate_bootstrap_uses_its_release_version_and_bounded_concurrency():
    job = load('ci-candidates.yml')['jobs']['candidate']
    assert job['strategy']['max-parallel'] == 4
    installers = [s for s in job['steps'] if s.get('name', '').startswith('Install xlings on')]
    assert len(installers) == 2
    assert '$XLINGS_VERSION/tools/other/quick_install.sh' in installers[0]['run']
    assert '$env:XLINGS_VERSION/tools/other/quick_install.ps1' in installers[1]['run']
    assert all('/main/' not in s['run'] for s in installers)
