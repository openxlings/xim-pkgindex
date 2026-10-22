"""Repository rollout policy; package parsing stays in the upstream updater."""
from urllib.parse import urlsplit


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
