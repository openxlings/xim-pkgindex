"""The Vulkan drivers this index publishes, and what each platform gets.

WHY THE TWO ARE TESTED TOGETHER. `xim:mesa-lavapipe` and `xim:moltenvk` answer
one question -- "this machine enumerates no Vulkan device" -- on three
platforms, and a consumer addresses whichever it is the same way. That sameness
is a property of the pair, not of either recipe, so the assertions that state
it live here rather than in two files that could drift apart.

The denominator comes from the tree: every recipe that places a Vulkan ICD
manifest is a subject, so a third driver is covered the moment it is written.
"""
import glob
import os
import re

import pytest

from tests.lib.platform_utils import project_root

# The layout both payloads use, and the string that identifies a member of this
# family. A recipe that places an ICD manifest anywhere else is not one of
# these, and a recipe that stops placing one stops being a subject -- which is
# why the guard below asserts the family is not empty.
ICD_REL = "share/vulkan/icd.d"


def _code(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("--"))


def _icd_recipes():
    out = []
    for p in sorted(glob.glob(os.path.join(project_root(), "pkgs", "*", "*.lua"))):
        with open(p, encoding="utf-8") as f:
            text = f.read()
        if ICD_REL in _code(text):
            out.append((os.path.relpath(p, project_root()), text))
    return out


# The two halves of the ICD-placing set, named because they are different
# KINDS of package and the assertions below only hold for one of them.
#
#   DRIVERS      ship a driver of their own, repacked into the shared layout.
#   NOT_DRIVERS  place a manifest without shipping a driver: `mesa` builds RADV
#                from source into a subos, and `nvidia-gl-host-link` is a
#                sentinel pointing at the HOST's installed driver.
DRIVERS     = ("pkgs/m/mesa-lavapipe.lua", "pkgs/m/moltenvk.lua")
NOT_DRIVERS = ("pkgs/m/mesa.lua", "pkgs/n/nvidia-gl-host-link.lua")


def _drivers():
    return [(p, t) for p, t in _icd_recipes() if p in DRIVERS]


def test_every_icd_placer_is_accounted_for():
    """THE DENOMINATOR, AND IT IS TWO-SIDED.

    A subject set computed from the tree can go empty, and an empty one passes
    every assertion below. It can also GROW: a third Vulkan driver added to
    this index would be a subject nobody classified, and the assertions here
    would simply not run for it. So the set is compared for equality rather
    than for membership -- a new ICD placer fails this until someone decides
    which half it belongs to.
    """
    seen = {p for p, _ in _icd_recipes()}
    known = set(DRIVERS) | set(NOT_DRIVERS)
    assert seen == known, (
        "the set of recipes placing a Vulkan ICD manifest changed.\n"
        f"  unclassified: {sorted(seen - known)}\n"
        f"  missing:      {sorted(known - seen)}"
    )


@pytest.mark.static
@pytest.mark.parametrize("rel,text", _drivers(), ids=[p for p, _ in _drivers()])
class TestVulkanDrivers:
    def test_the_manifest_path_is_rewritten(self, rel, text):
        """The ICD manifest names its library RELATIVE TO ITSELF, and both
        payloads separate the manifest from the driver. The loader resolves
        that path against the manifest it read, so a manifest left as upstream
        wrote it names a file that is not there -- and the loader's answer to
        that is to skip the driver, not to fail. A machine with one driver
        installed then enumerates no device, which reads exactly like a machine
        with none."""
        code = _code(text)
        assert 'library_path' in code, f"{rel} does not rewrite the ICD's library_path"

    def test_the_completeness_check_names_a_driver(self, rel, text):
        """`install()` must end by asserting the driver file exists. Both
        payloads are two files, and a move that produced only the manifest
        would otherwise install cleanly and place nothing that can be loaded."""
        code = _code(text)
        assert re.search(r'os\.isfile\(path\.join\(dir, "lib"', code), \
            f"{rel} does not check that the driver landed in lib/"

    def test_the_subos_view_is_linux_only(self, rel, text):
        """`graphics.declare_vulkan_icd` and `declare_subos_env` write into a
        SubOS view and set the loader's search variables in it. Neither exists
        on macOS or Windows -- dyld and the PE loader resolve normally, and the
        Vulkan loader there reads the registry or `VK_DRIVER_FILES`. A recipe
        that calls them unconditionally would place nothing and say nothing."""
        code = _code(text)
        if "declare_vulkan_icd" not in code:
            return
        assert re.search(r'if is_host\("linux"\) then', code), \
            f"{rel} calls the SubOS helpers on every host"

    def test_every_declared_platform_has_a_download_and_a_hash(self, rel, text):
        code = _code(text)
        xpm = code[code.index("xpm = {"):]
        blocks = re.findall(r'^\s{8}(linux|windows|macosx) = \{(.*?)^\s{8}\},',
                            xpm, re.M | re.S)
        assert blocks, f"{rel}: no platform block found under xpm"
        for plat, body in blocks:
            assert re.search(r'sha256\s*=', body), f"{rel}: the {plat} block declares no sha256"
            assert "GLOBAL" in body and "CN" in body, \
                f"{rel}: the {plat} block does not name both mirrors"


@pytest.mark.static
def test_moltenvk_states_the_portability_requirement():
    """THE ONE THING NO INSTALL HOOK CAN DO FOR THE CONSUMER.

    MoltenVK's manifest declares `is_portability_driver`, and the Vulkan loader
    hides such a driver from `vkEnumeratePhysicalDevices` unless the instance
    opts in. A program that does not opt in sees no device and cannot tell that
    apart from a machine with no GPU. The packaging cannot supply that opt-in,
    so the recipe has to say so -- this asserts that it does, because a
    requirement recorded nowhere is a requirement nobody meets.
    """
    p = os.path.join(project_root(), "pkgs", "m", "moltenvk.lua")
    with open(p, encoding="utf-8") as f:
        text = f.read()
    assert "VK_KHR_portability_enumeration" in text
    assert "VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR" in text
    assert "VK_KHR_portability_subset" in text


@pytest.mark.static
def test_the_windows_lavapipe_records_that_it_is_a_redistribution():
    """Mesa publishes no Windows binaries, so that payload comes from a third
    party. Where a payload came from is not a detail on the platform where the
    answer differs from every other platform's."""
    p = os.path.join(project_root(), "pkgs", "m", "mesa-lavapipe.lua")
    with open(p, encoding="utf-8") as f:
        text = f.read()
    if "windows = {" not in _code(text):
        pytest.skip("no windows section")
    assert "mesa-dist-win" in text, \
        "the windows section does not name where its payload comes from"
    assert "MSVCP140" in text or "VCRUNTIME140" in text, \
        "the measurement that decided between the available builds is not recorded"
