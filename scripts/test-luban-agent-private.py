#!/usr/bin/env python3
"""Real rootfs, owner configuration, build, proxy and offline-export acceptance."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading

REPO = Path(__file__).resolve().parents[1]


def exact(conn, count):
    data = b""
    while len(data) < count:
        part = conn.recv(count - len(data))
        if not part:
            raise EOFError
        data += part
    return data


class ProxyFixture:
    def __init__(self):
        self.domains = []
        self.socket = socket.socket()
        self.socket.bind(("127.0.0.1", 0))
        self.socket.listen()
        self.socket.settimeout(0.5)
        self.port = self.socket.getsockname()[1]
        self.running = True
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while self.running:
            try:
                conn, _ = self.socket.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            threading.Thread(target=self.request, args=(conn,), daemon=True).start()

    def request(self, conn):
        with conn:
            conn.settimeout(8)
            try:
                version, methods = exact(conn, 2)
                assert version == 5 and 0 in exact(conn, methods)
                conn.sendall(b"\x05\x00")
                header = exact(conn, 4)
                assert header == b"\x05\x01\x00\x03", header
                name = exact(conn, exact(conn, 1)[0]).decode()
                assert exact(conn, 2) == b"\x00\x50"
                self.domains.append(name)
                conn.sendall(b"\x05\x00\x00\x01\x7f\x00\x00\x01\x00\x50")
                request = b""
                while b"\r\n\r\n" not in request:
                    request += exact(conn, 1)
                conn.sendall(b"HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK")
            except (OSError, EOFError, AssertionError):
                return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", help="Reuse an explicitly supplied disposable test home")
    parser.add_argument("--busybox", action="store_true", help="Use the local AppArmor-compatible BusyBox entry")
    args = parser.parse_args()
    home = Path(args.home).resolve() if args.home else Path(tempfile.mkdtemp(prefix="luban-agent-"))
    home.mkdir(parents=True, exist_ok=True)
    (home / "bin").mkdir(exist_ok=True)
    entry = home / "bin/xlings"
    if not entry.exists():
        shutil.copy2(Path(shutil.which("xlings")).resolve(), entry)
    env = {**os.environ, "XLINGS_HOME": str(home), "XLINGS_NON_INTERACTIVE": "1",
           "PATH": f"{home}/bin:/usr/bin:/bin", "LC_ALL": "C.UTF-8"}
    for key in ("XLINGS_SUBOS_MODE", "XLINGS_ACTIVE_SUBOS", "XLINGS_PROJECT_DIR", "XLINGS_BROKER_SOCKET", "XLINGS_SESSION_FD"):
        env.pop(key, None)
    prefix = ["/usr/bin/busybox", "env"] if args.busybox else []
    log = home / "acceptance.log"

    def run(argv, expected=0, timeout=900):
        result = subprocess.run(prefix + [str(v) for v in argv], cwd="/tmp", env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        with log.open("a") as f:
            f.write("$ " + " ".join(map(str, argv)) + "\n" + result.stdout + "\n")
        assert result.returncode == expected, result.stdout[-5000:]
        return result.stdout

    def x(*argv, **kwargs):
        return run([entry, *argv], **kwargs)

    def inside(script, **kwargs):
        return x("subos", "exec", "agent", "--timeout", "90s", "--", "/bin/sh", "-c", script, **kwargs)

    proxy = ProxyFixture()
    try:
        x("self", "init")
        for recipe in ("pkgs/l/luban-tiny.lua", "pkgs/l/luban-core.lua", "pkgs/a/agent-private.lua", "pkgs/a/agent-workspace-private.lua"):
            x("config", "--add-xpkg", REPO / recipe)
        for recipe in ("pkgs/g/gcc.lua", "pkgs/g/gcc-runtime.lua", "pkgs/b/binutils.lua", "pkgs/o/openssl.lua", "pkgs/x/xz.lua"):
            shutil.copy2(REPO / recipe, home / "data/xim-pkgindex" / recipe)
        x("install", "subos:luban-tiny@0.2.0", "subos:luban-core@0.2.0", "local:agent-private@0.1.0", "config:agent-workspace-private@0.1.0", "xim:bwrap")
        if not (home / "subos/agent/rootfs/etc").is_dir():
            x("subos", "new", "agent", "--rootfs", "--from", "subos:luban-core@0.2.0")
        helper = home / "data/xpkgs/config-x-agent-workspace-private/0.1.0/agent-workspace-private"
        x("subos", "stop", "agent")
        endpoint = f"socks5h://127.0.0.1:{proxy.port}"
        run([helper, "agent", endpoint, "local:agent-private@0.1.0"])
        policy = json.loads(x("subos", "config", "agent", "--json"))
        assert policy["isolation"]["net"] == "proxy" and policy["isolation"]["no_degrade"]
        assert policy["resolved"]["from"] == "local:agent-private@0.1.0"
        assert len(policy["resolved"]["sha256"]) == 64
        inside('set -eu; printf "{\\"keep\\":true}\\n" > /root/.claude/settings.json; printf "fixture-secret" > /root/.claude/fixture-credentials')
        run([helper, "agent", endpoint, "local:agent-private@0.1.0"])
        inside('set -eu; grep -q keep /root/.claude/settings.json; test "$(cat /root/.claude/fixture-credentials)" = fixture-secret; test "$(stat -c %a /root/workspace)" = 700; test ! -e /usr/bin/apt-get; test ! -e /dev/video0; test "$HOME" = /root; test "$TZ" = UTC; test -z "${SSH_AUTH_SOCK:-}"; bash --version; fish --version; vim --version; nvim --version; git --version; mcpp --version; claude --version; g++ --version')
        x("subos", "cp", REPO / "tests/fixtures/luban_network_probe.cpp", "agent:/root/workspace/network.cpp")
        inside(f"set -eu; g++ -DHOST_SERVICE_PORT={proxy.port} /root/workspace/network.cpp -o /root/workspace/network; /root/workspace/network direct; /root/workspace/network proxy")
        assert "example.com" in proxy.domains, "DNS name must reach the owner-side SOCKS fixture"
        inside('set -eu; cd /root/workspace; if [ ! -d smoke-mcpp ]; then mcpp new smoke-mcpp; fi; cd smoke-mcpp; mcpp build --offline; mcpp run --offline')
        x("subos", "config", "agent", "--proxy", "socks5h://127.0.0.1:1")
        x("subos", "stop", "agent")
        inside('set -eu; /root/workspace/network direct; if /root/workspace/network proxy; then exit 1; fi; echo no-direct-fallback')
        run([helper, "agent", endpoint, "local:agent-private@0.1.0"])
        x("subos", "stop", "agent")
        offline = Path(tempfile.mkdtemp(prefix="luban-offline-")) / "rootfs"
        x("subos", "export", "agent", "--rootfs", offline)
        bwrap = Path("/usr/bin/bwrap")
        if not bwrap.exists():
            bwrap = next((home / "data/xpkgs/xim-x-bwrap").glob("*/bwrap"))
        # Do not mask /tmp: the logical xlings prefix may live below it.
        run([bwrap, "--unshare-all", "--die-with-parent", "--ro-bind", offline, "/", "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/root", "--setenv", "HOME", "/root", "--setenv", "TMPDIR", "/root", "--setenv", "PATH", "/usr/bin:/bin", "--", "/bin/sh", "-c",
             'set -eu; xlings --version; fish --version; nvim --version; git --version; mcpp --version; claude --version; printf "int main(){return 0;}\\n" > /root/offline.cpp; g++ /root/offline.cpp -o /root/offline; /root/offline'])
        x("remove", "-y", "config:agent-workspace-private@0.1.0")
        assert (home / "subos/agent/rootfs/root/.claude/fixture-credentials").read_text() == "fixture-secret"
        retained = json.loads(x("subos", "config", "agent", "--json"))
        assert retained["resolved"] == policy["resolved"]
        print(f"PASS: tools, C++23 mcpp build, proxy, bypass denial, outage, idempotence, offline closure and uninstall retention. Evidence: {log}")
    finally:
        proxy.running = False
        proxy.socket.close()
        x("subos", "stop", "agent")


if __name__ == "__main__":
    main()
