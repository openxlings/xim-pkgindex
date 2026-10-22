"""Repository rollout policy; package parsing stays in the upstream updater."""
from datetime import date
from urllib.parse import urlsplit

UPDATE_INTERVAL_DAYS = 3
UPDATE_ANCHOR = date(2026, 10, 23)


def update_due(event, today):
    """Only scheduled scans are spaced; PR/manual validation always runs."""
    elapsed = (today - UPDATE_ANCHOR).days
    return event != "schedule" or elapsed >= 0 and elapsed % UPDATE_INTERVAL_DAYS == 0


APPROVED_CN_HOSTS = frozenset({
    'gitcode.com', 'mirrors.ustc.edu.cn', 'mirrors.tuna.tsinghua.edu.cn',
    'mirrors.bfsu.edu.cn', 'mirrors.nju.edu.cn', 'mirror.sjtu.edu.cn',
    'mirrors.sjtug.sjtu.edu.cn', 'mirrors.hust.edu.cn',
    'mirrors.cloud.tencent.com', 'cdn.npmmirror.com',
})


def rollout_reason(package, autoupdate):
    """Resource provenance policy; source parsing/verification belongs to the tool."""
    resources = autoupdate.get('resources', {})
    if not resources or not isinstance(resources, dict):
        return 'resources must declare reviewed targets'

    def leaves(value):
        if isinstance(value, str):
            return [value]
        if not isinstance(value, dict) or not value:
            raise ValueError('empty or invalid URL matrix')
        return [url for child in value.values() for url in leaves(child)]

    try:
        for region, target in resources.items():
            if isinstance(target, str):
                target = {'url': target}
            for url in leaves(target['url']):
                parsed = urlsplit(url)
                if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
                    return 'candidate resources must use public HTTPS without credentials'
                if region == 'CN' and parsed.hostname not in APPROVED_CN_HOSTS:
                    return 'CN target needs a reviewed institutional or existing resource-service mirror'
    except (KeyError, TypeError, ValueError, AttributeError):
        return 'invalid resource target declaration'
    return None


if __name__ == '__main__':
    import argparse
    from datetime import datetime, timezone
    from pathlib import Path

    parser = argparse.ArgumentParser(description='Decide the repository update cadence in UTC')
    parser.add_argument('--event', required=True)
    parser.add_argument('--date', type=date.fromisoformat)
    parser.add_argument('--github-output', type=Path, required=True)
    args = parser.parse_args()
    due = update_due(args.event, args.date or datetime.now(timezone.utc).date())
    with args.github_output.open('a', encoding='utf-8') as stream:
        stream.write(f'due={str(due).lower()}\n')
    print(f'Update due: {due}; interval: {UPDATE_INTERVAL_DAYS} days; anchor: {UPDATE_ANCHOR}')
