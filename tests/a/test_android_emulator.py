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
    def test_linux_only(self, meta):
        assert meta.platforms.get("linux")
        assert "macosx" not in meta.platforms
        assert "windows" not in meta.platforms

    @pytest.mark.static
    def test_single_host_arch(self, source_text):
        m = re.search(r'archs\s*=\s*\{([^}]*)\}', source_text)
        assert m, "no archs field"
        archs = re.findall(r'"([^"]+)"', m.group(1))
        assert archs == ["x86_64"], (
            f"expected exactly one host arch (x86_64, matching upstream's "
            f"single Linux build), got {archs}"
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
    def test_the_only_warning_left_is_the_one_no_package_can_supply(self, source_text):
        # `/dev/kvm` is a kernel device. A warning is the right shape for
        # exactly that and for nothing that an xim package could provide, so
        # this asserts the count rather than the absence -- a second warning
        # appearing is the thing to catch.
        code = re.sub(r'--.*', '', source_text)
        warns = re.findall(r'log\.warn\(', code)
        assert len(warns) == 1, f"expected one warning (/dev/kvm), found {len(warns)}"
        i = code.index('log.warn(')
        assert '/dev/kvm' in code[max(0, i - 400):i + 400], (
            "the single remaining warning is not the KVM one")

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
        the same way _installed_pkgdir looks up this one. Skips rather than
        fails when it is not present -- this package's own install must
        not depend on that one having been installed too.
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
