"""Repository rollout policy; package parsing stays in the upstream updater."""
from datetime import date
from urllib.parse import urlsplit

UPDATE_INTERVAL_DAYS = 3
UPDATE_ANCHOR = date(2026, 10, 23)


def update_due(event, today):
    """Only scheduled scans are spaced; PR/manual validation always runs."""
    elapsed = (today - UPDATE_ANCHOR).days
    return event != "schedule" or elapsed >= 0 and elapsed % UPDATE_INTERVAL_DAYS == 0


def github_only_reason(package, autoupdate):
    def contains_cn(value, path=()):
        if isinstance(value, str) and urlsplit(value).hostname == 'gitcode.com':
            return True
        if value == 'XLINGS_RES':
            return True
        if not isinstance(value, dict):
            return False
        if value.get('source') == 'xlings-res':
            return True
        return any(key == 'CN' or contains_cn(child, (*path, key))
                   for key, child in value.items()
                   if (*path, key) != ('extensions', 'autoupdate'))

    if contains_cn(package):
        return 'package declares CN resources or an implicit multi-mirror resource source; this rollout only enables packages without CN'
    if autoupdate.get('provider'):
        return 'release discovery must use GitHub; vendor providers are outside this rollout'

    def urls(value):
        if isinstance(value, str):
            return [value]
        if not isinstance(value, dict) or not value or 'CN' in value:
            raise ValueError('invalid GitHub-only resource declaration')
        return [url for child in value.values() for url in urls(child)]

    try:
        resources = urls(autoupdate['url'])
        if not resources or any(urlsplit(url).scheme != 'https' or urlsplit(url).netloc != 'github.com'
                                for url in resources):
            return 'candidate resources must use HTTPS GitHub URLs; external registries and vendor downloads are excluded'
    except (KeyError, TypeError, ValueError):
        return 'autoupdate must declare only GitHub resources without CN mirrors'
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
