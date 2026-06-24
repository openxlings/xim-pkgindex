# TODO: aarch64 上 `xlings install mcpp` 验证 + url_template arch 修复

**日期**: 2026-06-24
**状态**: 待做(已登记,先不做)
**仓库**: `openxlings/xim-pkgindex`(+ 验证涉及 `openxlings/xlings` resolver)

## 现状(2026-06-24 复核后更正)
**aarch64 的 `xlings install mcpp` 其实基本已能用**,不是想象中的「无条目」缺口:
- xim resolver 的 xpm 块**按 OS 分**(`linux`/`macosx`/`windows`,见
  `xlings/src/core/xim/resolver.cppm:34`),aarch64 Linux 主机也命中 `xpm.linux` 块。
- `XLINGS_RES` 的下载 URL **带主机 arch** 拼接(`xlings/src/core/xim/installer.cppm:148-162`):
  `…/mcpp/releases/download/{ver}/mcpp-{ver}-{os}-{detect_arch_()}.{ext}`,
  `detect_arch_()` 在 aarch64 返回 `aarch64`(编译期 `__aarch64__`)。
- 即解析出 `mcpp-0.0.61-linux-aarch64.tar.gz` —— 该 asset 已镜像到
  `xlings-res/mcpp`(GitHub + GitCode,URL 实测 200)。

## 还剩的小事
1. **真机/qemu 验证**:在真 aarch64(或 qemu-user)上跑 `xlings install mcpp` 确认
   端到端解析+下载+运行 `mcpp 0.0.61`。这是唯一有真实价值的检查(目前只在 x86_64
   上验证了 URL + 解析逻辑)。
2. **`pkgs/m/mcpp.lua` 的 `url_template` 死代码修复**:linux 块 `url_template` 硬编码
   `mcpp-{version}-linux-x86_64.tar.gz`。它**只**是「版本未标 `XLINGS_RES`」时的回退,
   当前所有版本都标了 `XLINGS_RES` 故为死代码;但为正确性应改成 arch 感知模板
   (或文档注明)。低优先。
3. **(可选)sha256**:`XLINGS_RES` 条目无 sha256,无完整性校验——但这对所有 arch 一样,
   非 aarch64 特有。

## 不阻塞的原因
install.sh 一键脚本已直连 release 覆盖 aarch64 用户(WS6,实测 200 + 装出 0.0.61),
xim 路径只是「锦上添花 + 待验证」。
