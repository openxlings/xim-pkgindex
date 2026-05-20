---
name: pr-workflow
description: Use for ALL code changes — every modification to pkgs/, tests/, or scripts/ MUST go through a PR with CI verification before merging. No direct pushes to main. Covers branch creation, PR submission, CI monitoring, and merge rules.
---

# PR 工作流规范

## 核心原则

**所有代码变更必须通过 PR + CI 验证后才能合并到 main。禁止直接 push 到 main。**

这条规则没有例外——无论是新增包、版本升级、bug 修复、测试变更还是 skill 文件修改。

## 为什么

- main 分支是 xlings 用户直接拉取的包索引，直接 push 的错误会立即影响所有用户
- CI 包含 static analysis、isolation compliance、index registration、多平台 install/uninstall 测试
- 跳过 CI 意味着跳过这些保护，一个坏的 lua 语法就能让所有用户安装失败

## 标准流程

### 1. 创建分支

```bash
git fetch origin main
git checkout -b <type>/<scope> origin/main
```

分支命名规范：
- `feat/<pkg-name>` — 新增包
- `feat/<pkg-name>-<version>` — 版本升级
- `fix/<pkg-name>-<description>` — 修复
- `feat/spec-<name>` — 规范/测试变更

### 2. 提交变更

```bash
git add <specific-files>
git commit -m "<type>(<scope>): <description>"
```

commit message 规范：
- `feat(mcpp): bump to 0.0.20 for all platforms`
- `fix(vc6): fix uninstall, register package.name`
- `feat(spec): add D1 spec check`

**不要 `git add .`**，只添加相关文件。

### 3. 推送并创建 PR

```bash
git push -u origin <branch>
gh pr create --title "<commit-style title>" --body "..." --base main
```

PR body 必须包含：
- **Summary**：改了什么、为什么
- **Test plan**：本地验证了什么、CI 需要验证什么

### 4. 等待 CI 通过

```bash
gh pr checks <pr-number>
```

CI 必须全部通过才能合并。包含：
- `static-and-isolation` — 静态分析 + 隔离合规（pytest）
- `index-registration` — 包索引注册测试
- `linux-test` / `windows-test` / `macos-install-test` — 多平台测试

### 5. CI 失败处理

CI 失败时：
1. 读取失败 job 的日志
2. 分析根因并修复
3. push 新 commit（不要 force push）
4. 等待新一轮 CI
5. 重复直到全部通过

### 6. 合并

CI 全绿后，通过 GitHub UI 或 CLI 合并：

```bash
gh pr merge <pr-number> --squash
```

## 禁止事项

| 操作 | 为什么禁止 |
|------|-----------|
| `git push origin main` | 绕过 CI 验证 |
| `gh pr merge` 时 CI 未通过 | 引入未验证的变更 |
| 一个 PR 混合不相关的变更 | 难以 review、难以 revert |
| force push 到已有 review 的 PR | 丢失 review 上下文 |

## 多个变更的处理

如果一次工作涉及多个不相关的变更（例如：版本升级 + spec 检测 + bug 修复），**拆成多个 PR**：

```
feat/mcpp-0.0.20     → PR #1: mcpp 版本升级
feat/vc6-chinese     → PR #2: vc6 中文版 + 卸载修复
feat/xpkg-spec-d1    → PR #3: spec 检测规则
```

每个 PR 独立基于最新 main，独立通过 CI，独立合并。

## 紧急修复

即使是紧急修复也必须走 PR：

```bash
git checkout -b hotfix/<description> origin/main
# ... 修复 ...
git push -u origin hotfix/<description>
gh pr create --title "fix: ..." --base main
# 等 CI 通过后合并
```

如果 CI 环境本身有问题导致无法通过，需要在 PR 中记录证据（日志截图/链接），经 maintainer 确认后才能合并。

## 与其他 skill 的关系

- `xpkg-updater`: 更新包版本时，自动走本 PR 流程（见其 `references/pr-ci-loop.md`）
- `xpkg-creater`: 新增包时，同样必须通过 PR
- 本 skill 是所有变更的**底线规范**，其他 skill 的流程都建立在此基础上
