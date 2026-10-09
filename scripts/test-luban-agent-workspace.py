#!/usr/bin/env python3
"""The Luban agent workspace, for real (Luban design §C8): made private with
`luban new <n> agent-workspace --proxy`, its persona and zone, its tools and a
C++23 build, its network (the proxy only, no fallback when it is down), and
its offline export -- against the xlings and luban on PATH."""
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
    args = parser.parse_args()
    home = Path(args.home).resolve() if args.home else Path(tempfile.mkdtemp(prefix="luban-agent-"))
    home.mkdir(parents=True, exist_ok=True)
    (home / "bin").mkdir(exist_ok=True)
    for tool in ("xlings", "luban"):
        entry = home / "bin" / tool
        if not entry.exists():
            found = shutil.which(tool)
            assert found, f"{tool} must be on PATH (luban ships with xlings since 2026.10.10.1)"
            shutil.copy2(Path(found).resolve(), entry)
    env = {**os.environ, "XLINGS_HOME": str(home), "XLINGS_NON_INTERACTIVE": "1",
           "PATH": f"{home}/bin:/usr/bin:/bin", "LC_ALL": "C.UTF-8", "LC_TIME": "xx_SENTINEL.UTF-8",
           "SECRET_TOKEN": "sentinel-secret-7731"}
    for key in ("XLINGS_SUBOS_MODE", "XLINGS_ACTIVE_SUBOS", "XLINGS_PROJECT_DIR", "XLINGS_BROKER_SOCKET",
                "XLINGS_SESSION_FD", "DISPLAY", "WAYLAND_DISPLAY"):
        env.pop(key, None)
    log = home / "acceptance.log"

    def run(argv, expected=0, timeout=1800):
        result = subprocess.run([str(v) for v in argv], cwd="/tmp", env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        with log.open("a") as f:
            f.write("$ " + " ".join(map(str, argv)) + "\n" + result.stdout + "\n")
        assert result.returncode == expected, result.stdout[-5000:]
        return result.stdout

    def x(*argv, **kwargs):
        return run([home / "bin/xlings", *argv], **kwargs)

    def luban(*argv, **kwargs):
        return run([home / "bin/luban", *argv], **kwargs)

    def inside(script, **kwargs):
        return luban("run", "agent", "--", "/bin/sh", "-c", script, **kwargs)

    proxy = ProxyFixture()
    try:
        # This checkout IS the home's index: its recipes as they will be
        # published (a copy dropped into a synced artifact index is not in its
        # catalog).
        config = home / ".xlings.json"
        if not config.exists():
            config.write_text(json.dumps({"mirror": "GLOBAL",
                                          "index_repos": [{"name": "xim", "url": str(REPO)}]}) + "\n")
        x("self", "init")
        x("install", "-y", "xim:bwrap")
        endpoint = f"socks5h://127.0.0.1:{proxy.port}"
        if not (home / "subos/agent").is_dir():
            luban("new", "agent", "agent-workspace", "--proxy", endpoint)

        # Private when it was made: the edition's policy, selected and locked.
        status = json.loads(luban("status", "agent", "--json"))
        policy = status["requested"]
        assert policy["isolation"]["net"] == "proxy" and policy["isolation"]["no_degrade"]
        assert policy["resolved"]["from"] == "xim:agent-private@2026.10.10.1", policy
        assert len(policy["resolved"]["sha256"]) == 64
        identity = status["identity"]
        assert len(identity["hostname"]) == 12 and identity["exposed"], identity
        persona = json.loads((home / "config/subos/agent/persona.json").read_text())

        # Inside: its tools, its persona, nothing of the host's environment.
        out = inside('set -eu; echo HOST=$(hostname); echo MID=$(cat /etc/machine-id); echo TZ=$TZ; env; '
                     'test "$HOME" = /root; test -z "${SSH_AUTH_SOCK:-}"; test ! -e /usr/bin/apt-get; test ! -e /dev/video0; '
                     'bash --version; fish --version; vim --version; nvim --version; git --version; mcpp --version; '
                     'claude --version; g++ --version')
        assert f"HOST={persona['hostname']}" in out and f"MID={persona['machine_id']}" in out, out[-2000:]
        assert "TZ=UTC" in out, "the fixture proxy cannot answer a zone lookup: UTC, never the host's"
        assert "SENTINEL" not in out and "sentinel-secret" not in out, "the host's environment crossed in"
        again = inside("hostname")
        assert again.strip().splitlines()[-1] == persona["hostname"], "the same persona every time"

        # Its network: the proxy, and nothing else.
        x("subos", "cp", REPO / "tests/fixtures/luban_network_probe.cpp", "agent:/root/workspace/network.cpp")
        inside(f"set -eu; mkdir -p /root/workspace; g++ -DHOST_SERVICE_PORT={proxy.port} /root/workspace/network.cpp -o /root/workspace/network; /root/workspace/network direct; /root/workspace/network proxy")
        assert "example.com" in proxy.domains, "a name must reach the proxy, resolved there"
        inside('set -eu; mkdir -p /root/workspace; cd /root/workspace; if [ ! -d smoke-mcpp ]; then mcpp new smoke-mcpp; fi; cd smoke-mcpp; mcpp build --offline; mcpp run --offline')
        luban("config", "agent", "proxy", "socks5h://127.0.0.1:1")
        inside('set -eu; /root/workspace/network direct; if /root/workspace/network proxy; then exit 1; fi; echo no-direct-fallback')
        luban("config", "agent", "proxy", endpoint)

        # Offline: the exported root runs its tools with no network and no home.
        x("subos", "stop", "agent")
        offline = Path(tempfile.mkdtemp(prefix="luban-offline-")) / "rootfs"
        luban("export", "agent", str(offline) + "/")
        bwrap = Path("/usr/bin/bwrap")
        if not bwrap.exists():
            candidates = sorted((home / "data/xpkgs/xim-x-bwrap").glob("*/bin/bwrap"))
            assert candidates, "bwrap payload executable missing"
            bwrap = candidates[-1]
        run([bwrap, "--unshare-all", "--die-with-parent", "--ro-bind", offline, "/", "--dev", "/dev", "--proc", "/proc",
             "--tmpfs", "/root", "--setenv", "HOME", "/root", "--setenv", "TMPDIR", "/root", "--setenv", "PATH",
             "/usr/bin:/bin", "--", "/bin/sh", "-c",
             'set -eu; xlings --version; luban --version; fish --version; nvim --version; git --version; mcpp --version; claude --version; printf "int main(){return 0;}\\n" > /root/offline.cpp; g++ /root/offline.cpp -o /root/offline; /root/offline'])
        print(f"PASS: private at creation, persona, tools, C++23 mcpp build, proxy-only network, no fallback, offline export. Evidence: {log}")
    finally:
        proxy.running = False
        proxy.socket.close()
        subprocess.run([str(home / "bin/xlings"), "subos", "stop", "agent"], cwd="/tmp", env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
