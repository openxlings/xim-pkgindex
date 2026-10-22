"""xlings install/remove 封装"""
import subprocess
import os


def _run_xlings(cmd: str, timeout: int = 180) -> tuple[int, str]:
    try:
        r = subprocess.run(
            ["bash", "-l", "-c", cmd],
            input="y\ny\ny\n",
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "HOME": os.path.expanduser("~")}
        )
        return r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"


class XlingsClient:

    @staticmethod
    def install(pkg_name: str, timeout: int = 180) -> tuple[bool, str]:
        code, out = _run_xlings(f"xlings install {pkg_name}", timeout=timeout)
        success = code == 0 and ("installed" in out.lower() or "already installed" in out.lower())
        return success, out

    @staticmethod
    def remove(pkg_name: str, timeout: int = 60) -> tuple[bool, str]:
        code, out = _run_xlings(f"xlings remove {pkg_name}", timeout=timeout)
        return code == 0, out

    @staticmethod
    def xim_add_xpkg(lua_path: str) -> tuple[bool, str]:
        # Index DB refresh latency can vary in CI, so keep a wider timeout budget.
        code, out = _run_xlings(f"xlings config --add-xpkg {lua_path}", timeout=45)
        # The output echoes the recipe path, so a package named like
        # `libgpg-error` must not read as a failure of its own registration.
        scan = out.replace(os.path.basename(lua_path), "<recipe>")
        scan = scan.replace(os.path.basename(lua_path).removesuffix(".lua"), "<package>").lower()
        has_error = "error" in scan and "please report" not in scan
        return code == 0 and not has_error, out
