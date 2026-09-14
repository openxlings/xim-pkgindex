#!/usr/bin/env bash
# Install the xlings the index CI pins (ci-test.yml) and put it on the job's
# PATH, then refresh the index: the release tarball bundles an index snapshot
# frozen at build time.
set -euo pipefail
export XLINGS_NON_INTERACTIVE=1
export XLINGS_VERSION="${XLINGS_VERSION:-v2026.8.10.1}"
curl -fsSL --retry 3 --retry-all-errors \
    https://raw.githubusercontent.com/openxlings/xlings/main/tools/other/quick_install.sh | bash
echo "XLINGS_HOME=$HOME/.xlings" >> "$GITHUB_ENV"
echo "$HOME/.xlings/bin" >> "$GITHUB_PATH"
echo "$HOME/.xlings/subos/current/bin" >> "$GITHUB_PATH"
"$HOME/.xlings/bin/xlings" --version
"$HOME/.xlings/bin/xlings" update
