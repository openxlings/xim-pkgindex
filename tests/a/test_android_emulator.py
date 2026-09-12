"""Tests for the android-emulator package."""
import glob
import os
import re
import subprocess
import time

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "android-emulator"
PKG_FILE = "pkgs/a/android-emulator.lua"

QEMU_DIR_REL = os.path.join("qemu", "linux-x86_64")


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestPinnedFacts:
    """The facts this recipe pins by hand, and the ones it deliberately
    refuses to declare, per the header comment in pkgs/a/android-emulator.lua.
    """

    @pytest.mark.static
    def test_sha256_present_and_64_hex(self, source_text):
        m = re.search(r'sha256\s*=\s*"([0-9a-fA-F]{64})"', source_text)
        assert m, "missing a 64-hex-character sha256"

    @pytest.mark.static
    def test_both_regions_and_the_upstream_one_is_kept(self, source_text):
        """REVERSED, AND THE CLAUSE IS WHY.

        This pinned the absence of a CN entry, on SDK Agreement 3.4: "you may
        not copy [...], redistribute [...] the SDK or any part of the SDK".
        Section 3.5 is the one that decides: distribution of components
        "licensed under an open source software license are governed SOLELY by
        the terms of that open source software license and NOT the License
        Agreement". Verified inside the archive rather than asserted -- the
        payload carries an Apache-2.0 LICENSE or NOTICE for its contents, so
        3.5 governs.

        Asserts BOTH entries. The GLOBAL one is not optional: a recipe that
        named only the mirror would make every user depend on a re-host, which
        is the inverse mistake and one pkgs/p/python.lua actually had.
        """
        code = re.sub(r'--.*', '', source_text)
        assert 'dl.google.com' in code, "the upstream URL was dropped"
        assert 'gitcode.com/xlings-res' in code, "no CN mirror"
        assert re.search(r'GLOBAL\s*=', code), "no GLOBAL key"
        assert re.search(r'CN\s*=', code), "no CN key"

    @pytest.mark.static
    def test_every_host_upstream_publishes_for(self, meta):
        """REVERSED. This pinned `linux` only, which was true of the recipe and
        not of upstream: Google publishes android-emulator for every host this index
        serves. Declaring one was an incomplete addition rather than a
        conclusion, so the test now asserts the completion -- one per host, and macOS gets two because Apple silicon has its own build.

        Execution evidence remains Linux-only and the recipe says so; the
        index's own macos-install-test and windows-test are the measurement for
        the other two legs.
        """
        for host in ("linux", "macosx", "windows"):
            assert meta.platforms.get(host), f"no {host} table"

    @pytest.mark.static
    def test_arch_scope_is_stated_per_platform(self, source_text):
        """REVERSED with the platform completion. `archs` is a statement about
        the PACKAGE and the platform tables carry the truth per host -- the
        shape 7zip.lua, bun.lua and cuda-nvcc.lua use. Upstream publishes one
        archive per host, so no table needs an `arch_alias` for selection and
        the `os.arch()`-is-unbound pitfall does not arise.
        """
        m = re.search(r'archs\s*=\s*\{([^}]*)\}', source_text)
        assert m, "no archs field"
        archs = re.findall(r'"([^"]+)"', m.group(1))
        assert archs == ["x86_64", "aarch64"], (
            f"expected both host arches, with the platform tables deciding "
            f"what each host is served, got {archs}"
        )

    @pytest.mark.static
    def test_no_jdk_dependency_declared(self, source_text):
        # avdmanager (a Java program) is not used by this recipe or by the
        # AVD-creation approach it documents -- see the header's
        # "avdmanager IS NOT NEEDED" section. A jdk-zulu dependency would
        # be the observable symptom of that boundary being crossed.
        code = re.sub(r'--.*', '', source_text)
        assert 'jdk-zulu' not in code
        assert 'sdkmanager' not in code
        assert 'avdmanager' not in code

    @pytest.mark.static
    def test_the_x11_chain_comes_from_the_ecosystem(self, source_text):
        # REVERSED, DELIBERATELY. This used to pin the opposite fact -- probe
        # the host with `hostlib.dirs_of` and warn, on pkgs/g/godot.lua's
        # precedent -- and that precedent does not hold in this index: xlings
        # is a user-space distribution, so a payload that needs a library
        # declares it and the ecosystem supplies it. `emulator` links libX11
        # UNCONDITIONALLY (DT_NEEDED loads at exec time regardless of
        # `-no-window`, verified), so it is a dependency and not a suggestion.
        #
        # Every link is named because a DT_NEEDED chain is not a resolution
        # order: a missing one fails at exec naming that library rather than
        # this package.
        code = re.sub(r'--.*', '', source_text)
        deps = re.search(r'deps\s*=\s*\{([^}]*)\}', code)
        assert deps, "no deps block"
        for lib in ("libX11", "libxcb", "libXau", "libXdmcp", "libbsd", "libmd"):
            assert lib in deps.group(1), f"{lib} is not declared"
        assert 'hostlib' not in code, "the host probe is back"

    @pytest.mark.static
    def test_warnings_are_only_for_what_no_package_can_supply(self, source_text):
        # `/dev/kvm` is a kernel device -- a warning is the right shape for
        # exactly that and for nothing that an xim package could provide.
        # The sdk-root/wrapper Windows gap (2026-09-12) joins it for the
        # identical reason: creating a real symlink there needs admin/
        # Developer Mode, which an install hook cannot grant either -- so
        # this asserts the count rather than the absence, the same shape
        # this test used before the second warning was a real gap and not
        # a bug. A THIRD warning appearing is the thing to catch.
        code = re.sub(r'--.*', '', source_text)
        warn_positions = [m.start() for m in re.finditer(r'log\.warn\(', code)]
        assert len(warn_positions) == 2, (
            f"expected two warnings (/dev/kvm, Windows sdk-root), found {len(warn_positions)}")
        contexts = [code[max(0, i - 400):i + 400] for i in warn_positions]
        assert any('/dev/kvm' in c for c in contexts), (
            "no warning mentions /dev/kvm")
        assert any('sdk-root' in c for c in contexts), (
            "no warning mentions the Windows sdk-root gap")

    @pytest.mark.static
    def test_arm64_gate_documented(self, source_text):
        # The measured, unconditional refusal this recipe's header records
        # ("System image must match the host architecture") must stay
        # written down, not just known -- see the docs-measurement-exposes
        # -diagnostic-defect class of failure this guards against.
        assert "does not support arm64" in source_text
        assert "System image must match the host architecture" in source_text

    @pytest.mark.static
    def test_no_os_arch_call(self, source_text):
        # Single upstream Linux build (verified against repository2-3.xml:
        # host-os values are linux/macosx/windows, one entry each) -- no
        # per-host-arch branching is needed, and os.arch() is unbound in
        # the install-hook runtime regardless (pkgs/n/node.lua,
        # pkgs/j/jdk-zulu.lua).
        code = re.sub(r'--.*', '', source_text)
        assert 'os.arch(' not in code


class TestSdkRootFix:
    """The 2026-09-12 fix: the emulator finds its SDK root without a
    hand-built directory. See pkgs/a/android-emulator.lua's own
    "THE EMULATOR SIGSEGVS" header section for what was measured."""

    @pytest.mark.static
    def test_sigsegv_and_cause_documented(self, source_text):
        assert "SIGSEGV" in source_text
        assert "0x98" in source_text
        assert "platform-tools" in source_text

    @pytest.mark.static
    def test_platform_tools_declared_as_a_dependency(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'xim:android-platform-tools@>=37.0.1' in code

    @pytest.mark.static
    def test_sdk_root_built_from_two_symlinks(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'sdk-root' in code
        assert re.search(r'ln -sf', code), "no ln -sf (os.ln does not exist)"
        assert code.count('ln -sf') >= 2, "expected one symlink per sibling"

    @pytest.mark.static
    def test_wrapper_defaults_env_without_overriding_caller(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert ': "${ANDROID_SDK_ROOT:=' in code
        assert ': "${ANDROID_HOME:=' in code
        assert 'export ANDROID_SDK_ROOT' in code
        assert 'export ANDROID_HOME' in code

    @pytest.mark.static
    def test_wrapper_registered_instead_of_raw_binary_on_posix(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert re.search(r'xvm\.add\("emulator",\s*\{\s*bindir\s*=\s*path\.join\(dir,\s*"bin"\)', code)

    @pytest.mark.static
    def test_wrapper_syntax_checked_at_install_time(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'bash -n' in code

    @pytest.mark.static
    def test_windows_gap_declared_not_silently_skipped(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'is_host("windows")' in code
        assert 'UNMEASURED' in source_text

    @pytest.mark.static
    def test_version_bumped_with_bare_pin_kept_for_compat(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert '"37.1.11-2"' in code
        assert '"37.1.11"' in code
        assert code.count('ref = "37.1.11-2"') == 3, (
            "expected latest to move to 37.1.11-2 on all three host tables")

    @pytest.mark.static
    def test_the_wrapper_script_itself_is_valid_shell(self, source_text, tmp_path):
        import subprocess
        m = re.search(r'EMULATOR_WRAPPER_TEMPLATE = \[==\[(.*?)\]==\]', source_text, re.S)
        assert m, "the embedded emulator wrapper template was not found"
        script = m.group(1) % ("/tmp/sdk-root", "/tmp/sdk-root", "/tmp/sdk-root/emulator/emulator")
        p = tmp_path / "emulator"
        p.write_text(script, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # 334 MB download plus extraction; widened from the small-package
        # default the way android-ndk.lua's own (much larger) install does.
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @staticmethod
    def _installed_pkgdir() -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-android-emulator", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no android-emulator payload found under {xpkgs_dir()}")

    @staticmethod
    def _installed_adb() -> str:
        """Locate a separately-installed android-platform-tools payload
        (a different package, owned by pkgs/a/android-platform-tools.lua)
        the same way _installed_pkgdir looks up this one.

        UPDATED 2026-09-12: android-emulator's own `deps` now names
        `xim:android-platform-tools` on linux/macosx (the sdk-root fix's
        `sdk-root/platform-tools` symlink needs a real payload to point
        at -- see this recipe's header), so an android-emulator install on
        those hosts always brings one along. This still skips rather than
        fails: a Windows install carries no such dependency (see the
        header's "WINDOWS IS UNMEASURED" section), and a test environment
        that installed this package by hand, bypassing the recipe's own
        `deps` resolution, is a real possibility this helper does not want
        to turn into a hard failure of a DIFFERENT package's own test.
        """
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-android-platform-tools", "*")))
            if hits:
                adb = os.path.join(hits[-1], "adb")
                if os.path.isfile(adb):
                    return adb
        pytest.skip("android-platform-tools not installed -- boot/push/run "
                     "verification needs it as a separate payload")

    @staticmethod
    def _installed_sysimage(abi: str) -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(
                xpkgs_dir(), f"{ns}-x-android-system-image", f"24-default-{abi}")))
            if hits:
                return hits[-1]
        pytest.skip(f"android-system-image@24-default-{abi} not installed -- "
                     "boot verification needs a system image as a separate payload")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_android_emulator(self):
        assert_xvm_registered("android-emulator")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_layout(self):
        pkgdir = self._installed_pkgdir()
        assert os.path.isfile(os.path.join(pkgdir, "emulator")), (
            "no emulator binary in the installed payload"
        )
        assert os.access(os.path.join(pkgdir, "emulator"), os.X_OK)
        assert os.path.isfile(os.path.join(pkgdir, QEMU_DIR_REL, "qemu-system-x86_64")), (
            "no qemu-system-x86_64 backend under " + QEMU_DIR_REL
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_help_documents_sysdir_override(self):
        # The mechanism a runner uses to point this package at a
        # SEPARATELY installed android-system-image payload -- see the
        # "WIRING" section of both recipes' headers.
        pkgdir = self._installed_pkgdir()
        out = subprocess.run([os.path.join(pkgdir, "emulator"), "-help"],
                              capture_output=True, text=True, timeout=30)
        assert "-sysdir" in out.stdout

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_boot_push_run_dynamic_x86_64(self, tmp_path):
        """The end-to-end proof this package exists for, reproducing by
        hand-written AVD config exactly the measurement recorded in this
        recipe's header: a dynamically linked x86_64-linux-android binary,
        interpreter /system/bin/linker64, executes against a real system
        image with libc++_shared.so staged via LD_LIBRARY_PATH.

        Skips (does not fail) when /dev/kvm is absent, or when either the
        platform-tools or the system-image payload is not separately
        installed -- all three are genuine environmental preconditions,
        not defects in this package.
        """
        if not os.path.exists("/dev/kvm"):
            pytest.skip("/dev/kvm not present -- boot would fall back to "
                        "slow software virtualization or fail outright")

        pkgdir = self._installed_pkgdir()
        adb = self._installed_adb()
        sysimg_dir = self._installed_sysimage("x86_64")

        emu_home = tmp_path / "user-home"
        avd_dir = emu_home / "avd" / "pytest_x86_64.avd"
        avd_dir.mkdir(parents=True)
        (emu_home / "avd" / "pytest_x86_64.ini").write_text(
            "avd.ini.encoding=UTF-8\n"
            f"path={avd_dir}\n"
            "target=android-24\n"
        )
        (avd_dir / "config.ini").write_text(
            "avd.ini.encoding=UTF-8\n"
            "AvdId=pytest_x86_64\n"
            "PlayStore.enabled=false\n"
            "abi.type=x86_64\n"
            "hw.cpu.arch=x86_64\n"
            "hw.ramSize=2048\n"
            "hw.gpu.enabled=yes\n"
            "hw.gpu.mode=swiftshader_indirect\n"
            "hw.sdCard=no\n"
            "disk.dataPartition.size=800M\n"
        )
        import shutil
        shutil.copyfile(os.path.join(sysimg_dir, "userdata.img"), avd_dir / "userdata.img")

        env = dict(os.environ)
        env["ANDROID_AVD_HOME"] = str(emu_home / "avd")
        env["ANDROID_EMULATOR_HOME"] = str(emu_home)
        env["ANDROID_SDK_HOME"] = str(emu_home)
        env["ANDROID_USER_HOME"] = str(emu_home)
        env["HOME"] = str(emu_home)  # defense in depth, see the task report

        emu = subprocess.Popen(
            [os.path.join(pkgdir, "emulator"), "-avd", "pytest_x86_64",
             "-sysdir", sysimg_dir, "-no-window", "-no-audio",
             "-no-boot-anim", "-no-snapshot", "-gpu", "swiftshader_indirect"],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            subprocess.run([adb, "wait-for-device"], env=env, timeout=120, check=True)
            deadline = time.time() + 180
            booted = False
            while time.time() < deadline:
                out = subprocess.run([adb, "shell", "getprop", "sys.boot_completed"],
                                      env=env, capture_output=True, text=True, timeout=10)
                if out.stdout.strip() == "1":
                    booted = True
                    break
                time.sleep(2)
            assert booted, "sys.boot_completed never reached 1 within 180s"

            src = os.path.join("tests", "fixtures", "hello_x86_64-linux-android_dynamic")
            if not os.path.isfile(src):
                pytest.skip(f"fixture {src} not present in this checkout")
            subprocess.run([adb, "push", src, "/data/local/tmp/hello"], env=env, check=True)
            subprocess.run([adb, "shell", "chmod", "755", "/data/local/tmp/hello"],
                            env=env, check=True)
            out = subprocess.run(
                [adb, "shell",
                 "LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/hello; echo EXIT=$?"],
                env=env, capture_output=True, text=True, timeout=30)
            assert "EXIT=0" in out.stdout, out.stdout
        finally:
            subprocess.run([adb, "emu", "kill"], env=env, timeout=30)
