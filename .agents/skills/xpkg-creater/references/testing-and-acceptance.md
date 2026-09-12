# testing & acceptance

新增/修改 xpkg 时，需要做两类验证：
1. **直接命令验证**（本地运行 xlings/xim/xvm 命令）
2. **测试集验证**（pytest 测试机/CI 同类流程）

---

## A. 直接命令验证流程（本地）

假设包名为 `<pkg>`，包文件为 `<path_to_pkg.lua>`。

```bash
# 1) 注册包到本地索引
xim --add-xpkg <path_to_pkg.lua>
```

```bash
# 2) 搜索是否可见
xim -s <pkg>
```

```bash
# 3) 安装
xim -i <pkg>
```

```bash
# 4) 验证可执行/版本（按包实际命令替换）
<pkg> --version
which <pkg>
```

```bash
# 5) 安装列表检查
xim -l <pkg>
```

```bash
# 6) 卸载
xim -r <pkg>
```

```bash
# 7) 卸载后复检
xim -l <pkg>
```

```bash
# 8) 测完把 recipe 从本地覆盖层拿掉(xlings ≥ 2026.9.12.1)
xlings config --remove-xpkg <pkg>
# 忘了也没关系:与主索引字节相同的副本会在下次 `xlings update` 时自动清掉;
# 改过的副本会一直留在覆盖层并压住主索引,`xlings config --list-xpkg` 能看到它。
```

验收重点：
- 能搜索到
- 能安装成功
- 命令可执行
- `config()` 后 xvm 路由正常
- 能干净卸载

---

## B. 测试集验证流程（pytest / CI 对齐）

### B1. 新增包必须新增测试文件

映射规则：
- `pkgs/n/mypackage.lua` -> `tests/n/test_mypackage.py`
- 包名有 `-` 时，在测试文件名中改为 `_`

### B2. 分层执行建议

```bash
# 必跑：静态 + 隔离
pytest tests/<group>/test_<pkg>.py -m "static or isolation" -v
```

```bash
# 必跑：索引注册
pytest tests/<group>/test_<pkg>.py -m index -v
```

```bash
# 推荐：生命周期
pytest tests/<group>/test_<pkg>.py -m lifecycle -v
```

```bash
# 推荐：功能验证
pytest tests/<group>/test_<pkg>.py -m verify -v
```

### B3. 提交 PR 前建议补跑

```bash
# 全仓静态检查
pytest tests/ -m static --tb=short -q
```

```bash
# 全仓隔离合规
pytest tests/ -m isolation --tb=short -q
```

```bash
# 全仓索引注册（需要已安装 xlings）
pytest tests/ -m index --tb=short -q
```

---

## C. PR 中必须写的测试信息

至少包含：
1. 本地直接命令验证结果（add/search/install/verify/remove）
2. pytest 执行命令与结果（至少 L0/L1/L2）
3. 如有未跑项，说明原因与风险
4. 说明 CI 是否预期通过（static/isolation/index）
