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
    assert "needs.scan.outputs.plan_ready == 'true'" in flow['jobs']['propose']['if']
    cache = [s for s in flow['jobs']['scan']['steps'] if s.get('uses', '').startswith('actions/cache/')]
    assert len(cache) == 1
    persist = flow['jobs']['persist']
    assert '!inputs.dry_run' in persist['if']
    assert "inputs.package == ''" in persist['if']
    assert 'github.event.repository.default_branch' in persist['if']
    assert persist['permissions'] == {'contents': 'write'}
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


def test_queue_is_preserved_after_partial_proposal_failure_and_persistence_is_gated():
    flow = load('xpkgindex-update.yml')
    proposal = flow['jobs']['propose']
    step = next(s for s in proposal['steps'] if s.get('id') == 'proposal')
    assert '--state-file .update-state.json' in step['run']
    dispatch = next(s for s in proposal['steps'] if s.get('name', '').startswith('Dispatch successfully'))
    assert 'always()' in dispatch['if']
    assert any(s.get('name') == 'Preserve proposal failures in the final gate' for s in proposal['steps'])
    assert 'persist' in flow['jobs']['result']['needs']
    assert '"$PERSIST" != failure' in flow['jobs']['result']['steps'][0]['run']
    for job in ['scan', 'propose']:
        upload = next(s for s in flow['jobs'][job]['steps'] if s.get('uses', '').startswith('actions/upload-artifact'))
        assert '.update-state.json' in upload['with']['path']
        assert '.update-state-store.json' in upload['with']['path']
        assert upload['with']['include-hidden-files'] is True


def test_package_budget_cannot_consume_the_entire_run_quota():
    policy = yaml.safe_load((ROOT / '.github/xpkgindex-update.yml').read_text())
    assert 0 < policy['package_requests'] < policy['request_budget']
    assert 0 < policy['package_download_bytes'] < policy['download_bytes']


def test_interrupted_scan_can_persist_a_checkpoint_without_a_complete_plan():
    flow = load('xpkgindex-update.yml')
    progress = next(s for s in flow['jobs']['scan']['steps'] if s.get('id') == 'progress')
    # Emit checkpoint readiness before plan parsing can fail; persist uses always().
    assert progress['run'].index("echo 'ready=true'") < progress['run'].index('Path("plan.json")')
    assert 'always()' in flow['jobs']['persist']['if']
    assert "needs.scan.result == 'success'" not in flow['jobs']['persist']['if']
    assert "needs.scan.result == 'success'" in flow['jobs']['propose']['if']
