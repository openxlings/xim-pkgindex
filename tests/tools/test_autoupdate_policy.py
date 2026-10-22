"""The rollout excludes CN packages and non-GitHub downloads without editing history."""
import pytest
from tools.autoupdate_policy import github_only_reason

pytestmark = pytest.mark.static


def test_github_release_and_archive_resources_are_eligible():
    auto = {'upstream': 'acme/foo', 'url': {'linux': {'x86_64': 'https://github.com/acme/foo/releases/download/${tag}/foo.zip'},
                                         'macosx': 'https://github.com/acme/foo/archive/${tag}.tar.gz'}}
    assert github_only_reason({'xpm': {}}, auto) is None


def test_historical_cn_resource_excludes_the_entire_package():
    package = {'xpm': {'linux': {'1.0': {'url': {'GLOBAL': 'https://github.com/acme/foo/a.zip', 'CN': 'https://gitcode.com/acme/foo/a.zip'}}}}}
    assert 'CN' in github_only_reason(package, {'url': 'https://github.com/acme/foo/${tag}.zip'})


@pytest.mark.parametrize('url', ['https://go.dev/dl/foo.zip', 'https://registry.npmjs.org/foo.tgz',
                                'https://github.com.evil.example/foo.zip', 'http://github.com/acme/foo/a.zip'])
def test_external_downloads_are_ineligible(url):
    assert github_only_reason({}, {'url': url})


def test_cn_in_update_matrix_is_ineligible_even_without_runtime_mirrors():
    assert github_only_reason({}, {'url': {'GLOBAL': 'https://github.com/acme/foo/${tag}.zip', 'CN': 'https://gitcode.com/a.zip'}})


def test_vendor_provider_is_ineligible():
    assert github_only_reason({}, {'provider': 'go', 'url': 'https://github.com/acme/foo/${tag}.zip'})


@pytest.mark.parametrize('platform', [{'source': 'xlings-res'}, {'1.0': {'url': 'XLINGS_RES'}}])
def test_implicit_multimirror_resources_are_ineligible(platform):
    assert github_only_reason({'xpm': {'linux': platform}}, {'url': 'https://github.com/acme/foo/${tag}.zip'})


@pytest.mark.parametrize('day,expected', [
    ('2026-10-22', False), ('2026-10-23', True), ('2026-10-24', False),
    ('2026-10-25', False), ('2026-10-26', True), ('2026-10-29', True),
    ('2026-10-31', False), ('2026-11-01', True), ('2027-01-03', True),
])
def test_three_day_schedule_survives_month_and_year_boundaries(day, expected):
    from datetime import date
    from tools.autoupdate_policy import update_due
    assert update_due('schedule', date.fromisoformat(day)) is expected


@pytest.mark.parametrize('event', ['pull_request', 'workflow_dispatch'])
def test_manual_and_pr_checks_run_even_between_scheduled_updates(event):
    from datetime import date
    from tools.autoupdate_policy import update_due
    assert update_due(event, date(2026, 10, 24))
