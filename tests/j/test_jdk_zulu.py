"""测试 jdk-zulu 包"""
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "jdk-zulu"
PKG_FILE = "pkgs/j/jdk-zulu.lua"

PLATFORMS = ("linux", "macosx", "windows")
# 2 个版本 (25 / 21 LTS) x 每平台的架构数: linux 2 + macosx 2 + windows 1 = 5
RESOURCE_COUNT = 10
VERSIONS = ("25.0.4", "21.0.12")


def _code(content: str) -> str:
    """去掉 lua 行注释, 让下面的静态断言只看真实声明 (注释里也写了这些字面量)"""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


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

    @pytest.mark.static
    def test_version_keys_are_openjdk_versions(self, meta):
        """版本键必须是 OpenJDK 版本 (java --version 显示的那个), 不是 Zulu 自己的 distro 版本"""
        code = _code(meta.raw_content)
        for version in VERSIONS:
            blocks = re.findall(rf'\["{re.escape(version)}"\]\s*=\s*\{{', code)
            assert len(blocks) == len(PLATFORMS), \
                f"{version} 版本块应覆盖 {PLATFORMS}, 实际 {len(blocks)} 个"
        # distro 版本 (zulu25.36.15) 只应出现在归档名里, 不能变成版本键
        assert '["25.36.15"]' not in code and '["21.52.15"]' not in code, \
            "distro 版本不应作为版本键"

    @pytest.mark.static
    def test_every_resource_has_cn_mirror(self, meta):
        """每个资源都要有 GLOBAL(upstream) + CN(gitcode) 两个源, 且 sha256 齐全"""
        code = _code(meta.raw_content)
        global_urls = re.findall(r'GLOBAL = "https://cdn\.azul\.com/zulu/bin/[^"]+"', code)
        cn_urls = re.findall(
            r'CN = "https://gitcode\.com/xlings-res/jdk-zulu/[^"]+"', code)
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', code)
        assert len(global_urls) == RESOURCE_COUNT, f"GLOBAL 源数量: {len(global_urls)}"
        assert len(cn_urls) == RESOURCE_COUNT, f"CN 源数量: {len(cn_urls)}"
        assert len(shas) == RESOURCE_COUNT, f"sha256 数量: {len(shas)}"

    @pytest.mark.static
    def test_no_crac_or_musl_builds(self, meta):
        """CRaC / musl 是不同产品, 不是架构, 不能混进来"""
        code = _code(meta.raw_content)
        assert "-crac-" not in code, "CRaC 构建不应出现在资源里"
        assert "_musl" not in code, "musl 构建不应出现在资源里"

    @pytest.mark.static
    def test_payload_derived_from_archive(self, meta):
        """解包目录带 distro 版本和 arch, 只能从归档名推导 (hook 里没有 os.arch)"""
        code = _code(meta.raw_content)
        assert "pkginfo.install_file()" in code, "payload 目录应从归档名推导"
        assert re.search(r'os\.host\(\)\s*==\s*"macosx"', code), \
            "install 必须区分 macosx 布局"
        assert re.search(r'"Contents"\s*,\s*"Home"', code), \
            "macOS payload 必须取内层 Contents/Home"

    @pytest.mark.static
    def test_shared_names_are_flavor_scoped(self, meta):
        """java/javac 等是所有 JDK 发行版共享的名字, 必须带 flavor 版本"""
        code = _code(meta.raw_content)
        assert re.search(r'version\s*=\s*flavor_version\(\)', code), \
            "共享程序名必须用 flavor_version() 注册"
        assert re.search(r'pkginfo\.version\(\)\s*\.\.\s*"-"\s*\.\.\s*FLAVOR', code), \
            "flavor_version 必须是 <version>-<flavor>"
        assert 'type = "group"' in code, \
            "binding root 应为 group 节点, 否则会留下永远失败的孤儿 shim"

    @pytest.mark.static
    def test_java_home_registered(self, meta):
        """JDK 只注册 shim 不给 JAVA_HOME 的话, maven/gradle 之类工具找不到它"""
        assert "JAVA_HOME" in _code(meta.raw_content), "config 应通过 xvm envs 提供 JAVA_HOME"


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # The Zulu 25 tarball is ~230MB; the default 180s can be tight on a
        # cold cache.
        assert_install_succeeds(PKG, timeout=420)


# ═══════════════════════════════════════════════════════════════════════
#  L4 provenance (D5-1) — LD_DEBUG=libs 是唯一能看见 dlopen 的验收口径
#
#  fontconfig 由 libfontmanager dlopen, 没有任何 DT_NEEDED 提到它, 静态清单
#  看不见; System.loadLibrary 的 LOAD_OK 也分不清「装载了」和「装载的是我们
#  的」(#578 的教训)。所以读 loader 自己的 `calling init:` 行 —— 每个真正
#  进入进程的对象一行, 带绝对路径。
#
#  探针跑的是 java.home 下的真实 bin/java 而不是 PATH 上的 shim: shim/xvm
#  链自己也是动态链接的宿主进程, LD_DEBUG 会把它们的对象混进同一条 stderr,
#  把「JDK 闭包」的测量搅浑。java.home 仍然是经 shim 问出来的, 所以 shim
#  路由本身已由 test_java_home_points_at_xpkg 覆盖。
# ═══════════════════════════════════════════════════════════════════════

_PROBE_FONT_JAVA = """\
import java.awt.*;
public class P {
    public static void main(String[] a) throws Exception {
        Toolkit.getDefaultToolkit();
        Canvas c = new Canvas();
        int w = c.getFontMetrics(new Font("Dialog", Font.PLAIN, 12)).stringWidth("hello");
        System.out.println("w=" + w);
    }
}
"""

_PROBE_AUDIO_JAVA = """\
import javax.sound.sampled.AudioSystem;
public class A {
    public static void main(String[] a) throws Exception {
        System.out.println("mixers=" + AudioSystem.getMixerInfo().length);
    }
}
"""


def _run(cmd: str, timeout: int = 120):
    return subprocess.run(
        ["bash", "-l", "-c", cmd],
        capture_output=True, text=True, timeout=timeout,
    )


def _real_java() -> str:
    """经 shim 问出 java.home, 返回载荷里的真实 bin/java"""
    r = _run("java -XshowSettings:properties -version 2>&1")
    out = r.stdout + r.stderr
    m = re.search(r"java\.home = (\S+)", out)
    assert m, f"拿不到 java.home: {out[:300]}"
    home = m.group(1)
    assert "jdk-zulu" in home, \
        f"java.home 不在 jdk-zulu 载荷里 (被系统 JDK 遮蔽?): {home}"
    return home + "/bin/java"


def _init_objects(java_bin: str, src) -> set:
    """LD_DEBUG=libs 跑探针, 返回所有 `calling init:` 对象的绝对路径集合"""
    r = _run(f"LD_DEBUG=libs '{java_bin}' -Djava.awt.headless=true '{src}'",
             timeout=180)
    assert r.returncode == 0, \
        f"探针没跑通 (exit={r.returncode}): {(r.stdout + r.stderr)[-400:]}"
    objs = {m.group(1) for m in re.finditer(r"calling init: (\S+)", r.stderr)}
    assert objs, "LD_DEBUG=libs 没产出 calling init: 行 (探针没跑在动态 java 上?)"
    return objs


def _is_host_path(obj: str) -> bool:
    # 宿主 = /lib*、/usr/lib* 开头; 我们的载荷都在 $XLINGS_HOME 下 (/home/...)
    return obj.startswith("/lib") or obj.startswith("/usr/lib")


_FONT_STACK = ("libfreetype", "libfontconfig", "libexpat",
               "libpng", "libbrotli", "libbz2")
# glibc 族 — 形态 H 下 INTERP 和 libc 本来就是宿主的, D5-3 切 core 时整体换
_GLIBC_FAMILY = re.compile(
    r"^(ld-linux|libc\.so|libc-|libdl\.so|libm\.so|libmvec\.so"
    r"|libpthread\.so|librt\.so)")
# alsa 链 — 「音频 = 宿主服务」是文档化例外: libjsound 不打 RUNPATH,
# libasound.so.2 从宿主解析, 换来的是发行版 pipewire/pulse 桥原样可用
_ALSA_CHAIN = ("libasound", "alsa-lib/", "pipewire", "spa-")


def _is_font_stack(obj: str) -> bool:
    name = obj.rsplit("/", 1)[-1]
    return any(s in name for s in _FONT_STACK)


def _is_glibc_family(obj: str) -> bool:
    return bool(_GLIBC_FAMILY.match(obj.rsplit("/", 1)[-1]))


def _is_alsa_chain(obj: str) -> bool:
    return any(s in obj for s in _ALSA_CHAIN)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_version(self):
        # java prints its version banner on stderr. Assert the vendor string too:
        # "25" alone would also match a pre-existing system JDK.
        assert_command_output("java -version 2>&1", contains="Zulu")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_javac_version(self):
        assert_command_output("javac -version", contains="25.0.4")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_points_at_xpkg(self):
        assert_command_output(
            "java -XshowSettings:properties -version 2>&1",
            regex=r"java\.home = .*jdk-zulu",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_env_reaches_jvm(self):
        """config 注册的 JAVA_HOME 必须真的进到 java 进程的环境里 (maven/gradle 靠它)"""
        assert_command_output(
            '''echo 'System.out.println("JH=[" + System.getenv("JAVA_HOME") + "]");' '''
            '''| jshell -s - 2>&1''',
            regex=r"JH=\[.*jdk-zulu.*\]",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_java(self):
        assert_xvm_registered("java")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_javac(self):
        assert_xvm_registered("javac")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_font_stack_provenance(self, tmp_path):
        """D5-1 验收: 字体链解析到我们的载荷, 宿主对象只剩 glibc 族 (+alsa 链)

        (a) 宿主字体栈为 0 — libfreetype/libfontconfig/libexpat/libpng/
            libbrotli/libbz2 一个都不许从宿主路径进入进程。brotli/bz2/png
            并不是我们要打的包: 它们只作为「宿主 freetype」的依赖被拖进来,
            我们的 freetype 只依赖 libc, 字体链归位后它们应整体消失。
        (b) 宿主路径对象扣除 glibc 族与 alsa 链后为 0。glibc 族是形态 H 的
            定义本身 (host INTERP + host libc; 我们的 leaf RUNPATH 绝不写
            glibc, 否则就是 #578 的段错误); alsa 链是文档化的「音频 = 宿主
            服务」例外, 见 test_audio_functional。

        探针故意只碰字体链、不碰音频: 实测宿主 libasound 的 pipewire 插件会
        拖进 dbus/systemd/gcrypt/lz4/zstd/... 一串随发行版漂移的宿主对象,
        它们全属于音频例外, 但逐名豁免它们就是在维护一张按发行版漂移的清单。
        所以 provenance 只对字体链断言, 音频只做功能验证 —— alsa 过滤器留在
        这里是防御性的, 别据此把音频加进本探针。
        """
        src = tmp_path / "P.java"
        src.write_text(_PROBE_FONT_JAVA, encoding="utf-8")
        objs = _init_objects(_real_java(), src)
        host = {o for o in objs if _is_host_path(o)}

        font_from_host = sorted(o for o in host if _is_font_stack(o))
        assert not font_from_host, \
            f"宿主字体栈进了进程 (fontconfig 载荷没 seal? RUNPATH 没打上?): {font_from_host}"

        residue = sorted(o for o in host
                         if not _is_glibc_family(o) and not _is_alsa_chain(o))
        assert not residue, \
            f"意外的宿主对象 (非 glibc 族、非 alsa 链): {residue}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_audio_functional(self, tmp_path):
        """javax.sound 走通即可 (exit 0), 不做纯净度断言。

        这是「音频 = 宿主服务」例外的功能面: libjsound.so 故意不打 RUNPATH,
        libasound.so.2 经 SONAME 回落到宿主, 换来的是发行版的 pipewire/pulse
        桥和音频配置原样可用。provenance 断言只属于字体链那条测试 —— 在这里
        断纯净度就是把文档化例外当缺陷测。
        """
        src = tmp_path / "A.java"
        src.write_text(_PROBE_AUDIO_JAVA, encoding="utf-8")
        r = _run(f"java '{src}'", timeout=120)
        assert r.returncode == 0, \
            f"音频探针没跑通 (exit={r.returncode}): {(r.stdout + r.stderr)[-300:]}"
        assert "mixers=" in r.stdout, f"探针没输出 mixer 数: {r.stdout[:200]}"
