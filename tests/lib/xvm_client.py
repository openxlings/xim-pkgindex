"""xvm 操作封装"""
import subprocess
import os
import json
from pathlib import Path
from tests.lib.platform_utils import subos_bin_dir, xlings_home


def _native_info(target: str) -> dict | None:
    """Read the candidate runner's actual SubOS registry, without legacy xvm."""
    path = Path(xlings_home()) / 'subos' / os.environ['XLINGS_TEST_SUBOS'] / '.xlings.json'
    try:
        workspace = json.loads(path.read_text(encoding='utf-8')).get('workspace') or {}
        if not isinstance(workspace, dict):
            raise ValueError('workspace must be an object')
        node = workspace.get(target)
        if node is None:
            return None
        active = node.get('active')
        installed = node.get('installed')
        if not isinstance(active, str) or not active or not isinstance(installed, list) or active not in installed:
            raise ValueError('active version must belong to installed versions')
        return {'program': target, 'version': active}
    except (OSError, ValueError, AttributeError) as exc:
        raise RuntimeError(f'cannot read native registration for {target}: {path}: {exc}') from exc


def _run(cmd: str, timeout: int = 10) -> tuple[int, str]:
    try:
        r = subprocess.run(
            ["bash", "-l", "-c", cmd],
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "HOME": os.path.expanduser("~")}
        )
        return r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"


class XvmClient:

    @staticmethod
    def info(target: str) -> dict | None:
        if os.environ.get('XLINGS_TEST_SUBOS'):
            return _native_info(target)
        code, out = _run(f"xvm info {target}")
        # xvm CLI 本身不可用 (127 = command not found) 时不得返回 None ——
        # None 会被 is_registered 折叠成「未注册」, 让断言在坏环境里静默
        # 误报业务否定 (silent-success 同族: 查询工具缺失 ≠ 查询结果为否)。
        # 只拦绝对不可用路径, 正常语义 (非 0 退出 / missing) 不变。
        # 背景: quick_install 的新 home 没有 xvm —— 它是 xim 包, 不是
        # xlings 自带; 先 `xlings install xvm`。
        if code == 127 or "command not found" in out:
            raise RuntimeError(
                f"xvm CLI 不可用 (exit={code}): {out[:120]!r} — "
                "这是环境缺前置, 不是包未注册; 先 `xlings install xvm`"
            )
        if code != 0 or "missing" in out.lower():
            return None
        result = {}
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("Program:"):
                result["program"] = line.split(":", 1)[1].strip()
            elif line.startswith("Version:"):
                result["version"] = line.split(":", 1)[1].strip()
            elif line.startswith("SPath:"):
                result["spath"] = line.split(":", 1)[1].strip()
            elif line.startswith("TPath:"):
                result["tpath"] = line.split(":", 1)[1].strip()
            elif line.startswith("Alias:"):
                result["alias"] = line.split(":", 1)[1].strip()
        return result if result else None

    @staticmethod
    def is_registered(target: str) -> bool:
        return XvmClient.info(target) is not None

    @staticmethod
    def shim_exists(target: str) -> bool:
        return os.path.isfile(os.path.join(subos_bin_dir(), target))
