"""Reviewed mirrors are mandatory admission targets; cadence is independent."""
import pytest
from tools.autoupdate_policy import rollout_reason

pytestmark = pytest.mark.static


def auto(cn=None):
    targets = {'GLOBAL': {'url': 'https://github.com/acme/foo/${tag}.zip', 'required': True}}
    if cn:
        targets['CN'] = {'url': cn, 'required': True}
    return {'source': 'https://github.com/acme/foo/releases', 'resources': targets}


def test_single_global_and_historical_cn_are_eligible():
    assert rollout_reason({'xpm': {'source': 'xlings-res'}}, auto()) is None


@pytest.mark.parametrize('host', ['gitcode.com', 'mirrors.ustc.edu.cn', 'mirrors.tuna.tsinghua.edu.cn', 'cdn.npmmirror.com'])
def test_reviewed_cn_is_required_and_eligible(host):
    assert rollout_reason({}, auto('https://' + host + '/foo/${version}.zip')) is None


def test_vendor_global_is_independent_of_discovery():
    declaration = auto()
    declaration['resources']['GLOBAL']['url'] = 'https://nodejs.org/dist/${tag}/node.zip'
    assert rollout_reason({}, declaration) is None


def test_unreviewed_mirror_is_rejected():
    assert rollout_reason({}, auto('https://mirrors.ustc.edu.cn.evil.example/${tag}.zip'))


def test_optional_target_is_selectable_by_a_reviewed_package_declaration():
    declaration = auto('https://mirrors.ustc.edu.cn/foo/${version}.zip')
    declaration['resources']['CN']['required'] = False
    assert rollout_reason({}, declaration) is None


@pytest.mark.parametrize('url', ['http://github.com/acme/foo/${tag}', 'https://secret:token@github.com/acme/foo/${tag}'])
def test_nonpublic_resource_declarations_are_rejected(url):
    declaration = auto()
    declaration['resources']['GLOBAL']['url'] = url
    assert rollout_reason({}, declaration)


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
