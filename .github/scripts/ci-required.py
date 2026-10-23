#!/usr/bin/env python3
"""Reject failed planning and any planned validation that did not succeed."""
import json
import sys


def failures(needs):
    if needs.get('plan', {}).get('result') != 'success':
        return ['plan did not succeed']
    flags = needs['plan']['outputs']
    expected = {name for name, value in flags.items() if value == 'true' and name != 'closure'}
    # install is a reusable workflow too; every caller job must be accounted for.
    errors = []
    for name, job in needs.items():
        if name == 'plan':
            continue
        status = job['result']
        if status in ('failure', 'cancelled') or (name in expected and status != 'success'):
            errors.append(f'{name}: {status}')
    errors.extend(f'{name}: missing result' for name in expected if name not in needs)
    return errors


if __name__ == '__main__':
    errors = failures(json.load(sys.stdin))
    if errors:
        sys.exit('\n'.join(errors))
    print('Every planned validation succeeded; other jobs were intentionally not selected.')
