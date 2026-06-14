# xim-pkgindex: VirtualBox + Ubuntu 24.04 包设计方案(v2)

> 状态: **设计草案 / 待 review**(尚未落地任何 `.lua` 包文件)
> 日期: 2026-06-14
> v2 变更(按 review 反馈): `virtualbox` 改为正常 `type = "package"`(可被 xlings/xvm 管理),新增 `type = "res"` 的 ISO 资源包(`ubuntu-desktop-iso` 等),整体尽量做到 **xlings 闭环管理** —— 轻便 / 解压即用 / 有命令的注册到 xvm。
> 目标: 为包索引新增「安装 VirtualBox 虚拟机」与「在其内安装 Ubuntu 24.04 系统」的能力,要求支持 Windows(并尽量兼顾 Linux / macOS)。

---

## 0. TL;DR(给 review 的一页纸)

- **拆 4 个包**,职责单一、尽量 xlings 闭环:
  1. `virtualbox` —— **`type = "package"`**,解压式安装 VirtualBox 用户态(`VBoxManage`/`VBoxHeadless`/`VBoxSVC`/GUI),**注册到 xvm**,版本受 xlings 管理。
  2. `ubuntu-desktop-iso` —— **`type = "res"`**(新类型),把 Ubuntu 24.04 desktop ISO 作为受管资源下载/缓存,供他包按依赖定位。
  3. `virtualbox-ubuntu` —— `type = "package"`,依赖 `virtualbox` + `ubuntu-desktop-iso`,用 **xvm 路由的 `VBoxManage unattended install`** 无人值守建好一台 Ubuntu 虚拟机。
  4. `virtualbox-extpack`(可选)—— `type = "package"`,依赖 `virtualbox`,装同版本 Oracle 扩展包。
- **xlings 闭环的真实边界(调研重点结论,✅ 已 review 认可)**:VirtualBox **用户态 100% 可解压 + xvm 注册**(`VBoxManage` 解压即用,可创建/配置/列出 VM);但**让 VM 真正开机运行需要一次性特权的内核驱动 `vboxdrv`**(Linux 内核模块 / Windows 驱动 / macOS kext)。这一步无法塞进 xvm,只能在 `config()` 里做最小化的特权动作并明确提示。详见 §2.3 与 §6。
- **`VBoxManage` 等命令全部注册进 xvm**(`xvm.add("VBoxManage", {bindir=...})`),与 `cmake.lua` 同范式 → 命令受 xlings 路由、可多版本共存。
- **版本基线**:VirtualBox **7.2.8**(7.1 已 EOL);Ubuntu **24.04.4 LTS**(Noble)。
- **ISO 走 `res` 包独立管理**,不进 xlings-res 镜像(3~6G 过大),官方直链 + CN 镜像 URL。
- **待 review 决策见 §7**。

---

## 1. 调研结论

### 1.1 VirtualBox 版本与下载

| 项 | 结论 |
| -- | -- |
| 当前稳定版 | **7.2.8**(build 173730,2026-04-21) |
| 7.1 系列 | 7.1.18 为最后版,**2026-03 已 EOL**,不作默认 |
| 下载根 | `https://download.virtualbox.org/virtualbox/7.2.8/` |
| Windows | `VirtualBox-7.2.8-173730-Win.exe`(170M,内含可抽取的 MSI) |
| macOS Intel / ARM | `...-OSX.dmg`(144M)/ `...-macOSArm64.dmg`(153M) |
| Linux 通用 | `VirtualBox-7.2.8-173730-Linux_amd64.run`(127M) |
| 扩展包(全平台同文件) | `Oracle_VirtualBox_Extension_Pack-7.2.8.vbox-extpack`(20M) |

### 1.2 闭环可行性调研:用户态可解压,驱动不可绕过

**关键事实(已核实)**:VirtualBox 把 `vboxdrv` 内核模块装入系统内核;**没有该模块时,`VBoxManage` / VirtualBox Manager 仍可配置虚拟机,但虚拟机无法启动**。另有 `vboxnetflt`/`vboxnetadp` 网络驱动。

推论 —— 把 VirtualBox 拆成两层看:

| 层 | 内容 | 能否 xlings/xvm 闭环 |
| -- | -- | -- |
| **用户态(userspace)** | `VBoxManage`、`VBoxHeadless`、`VBoxSVC`、`VirtualBox` GUI、`VBoxManage unattended` | ✅ 解压即用,`xvm.add` 注册,版本受管 |
| **内核态(driver)** | `vboxdrv` 内核模块 + 网络驱动 | ❌ 必须一次性特权安装,才能让 VM **开机** |

所以本方案的策略是:**能解压 + 路由的全部走 xvm 闭环;不可避免的内核驱动,隔离成 `config()` 里一个最小、显式、可检测的特权步骤**,并在日志/文档讲清楚。这是 VirtualBox 物理上能做到的"最闭环"形态。

> 旁注:若把"零特权、纯用户态闭环"作为最高优先级,技术上更契合的后端是 **QEMU(TCG 软件模拟无需内核驱动,有静态可解压构建)**;但用户本次明确要 VirtualBox,故 QEMU 仅作 §7 备选记录。

### 1.3 跨平台自动化核心:`VBoxManage unattended install`

三大平台命令一致,一条命令创建 + 无人值守装好 Ubuntu:
```
VBoxManage unattended install <vm> --iso=<ubuntu.iso> \
    --user=<u> --password=<p> --full-user-name="<u>" \
    --hostname=ubuntu2404.local --install-additions --start-vm=headless
```
内置 subiquity/preseed 应答生成;未指定账号时默认 `vboxuser`/`changeme`。

### 1.4 Ubuntu 24.04

| 项 | 结论 |
| -- | -- |
| 当前点版本 | **24.04.4 LTS**(Noble,2026-02) |
| 下载根 | `https://releases.ubuntu.com/24.04/` |
| Desktop | `ubuntu-24.04.4-desktop-amd64.iso`(6.2G) |
| Server | `ubuntu-24.04.4-live-server-amd64.iso`(3.2G) |
| CN 镜像 | 清华/中科大,如 `https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04/` |

---

## 2. 设计目标与约束

### 2.1 目标
1. `xlings install virtualbox` —— 跨平台装好 VirtualBox,命令受 xvm 路由。
2. `xlings install ubuntu-desktop-iso` —— 把 ISO 作为受管资源拉到本地缓存。
3. `xlings install virtualbox-ubuntu` —— 一键得到一台已装好的 Ubuntu 24.04 VM。
4. 拆包清晰、可独立安装、可组合;后续易扩展(如 `virtualbox-debian` 等)。

### 2.2 xpkg V1 合规约束
- `spec = "1"`,必填 `name/description/type/xpm`;hook 只用标准 Lua + `xim.libxpkg.*`。
- `package` 类型:解压安装到 `pkginfo.install_dir()`,`config()` 内 `xvm.add(prog, {bindir=...})`(与 `cmake.lua` 同范式)。
- 平台差异用 `xpm.<platform>` 分区 + hook 内 `os.host()` 选文件名(`cmake.lua`/`mdbook.lua` 已有先例,合规)。

### 2.3 `type = "res"` 新类型(需确认框架支持)
- 现仓库无 `type = "res"` 先例;V1 spec 的 type 枚举为 `package|script|template|config`。
- 设计意图:`res` 表示"只下载/缓存资源、不产生可执行命令、不注册 xvm"的纯数据包,供他包通过 `pkginfo.dep_install_dir("<res>")` 定位。
- **开放项**:需确认 xlings 框架是否已识别/将支持 `res`。**回退方案**:用 `type = "package"` + 空 `config()`(不 `xvm.add`)等价实现,先落地再按框架演进改 `res`。详见 §7。

---

## 3. 包拆分总览

```
ubuntu-desktop-iso (res)  ─┐
                           ├─ deps ─►  virtualbox-ubuntu (package, 编排)
virtualbox (package) ──────┘                 │ 用 xvm 路由的 VBoxManage
   ▲                                         
   └── deps ── virtualbox-extpack (package, 可选)
```

| 包名 | type | 平台 | 依赖 | 作用 | xvm 注册 |
| -- | -- | -- | -- | -- | -- |
| `virtualbox` | package | win/linux/macosx | — | 解压用户态 + 内核驱动(config 特权步) | `VBoxManage` 等 ✅ |
| `ubuntu-desktop-iso` | res | (任意宿主) | — | 下载/缓存 Ubuntu 24.04 desktop ISO | 否(纯资源) |
| `virtualbox-ubuntu` | package | win/linux/macosx | `virtualbox`, `ubuntu-desktop-iso` | 无人值守建 Ubuntu VM | 可选 launcher ✅ |
| `virtualbox-extpack` | package | win/linux/macosx | `virtualbox` | 同版本扩展包(可选) | 否 |

---

## 4. 各包详细设计

### 4.1 `virtualbox`(基础包,`type = "package"`)

**元数据要点**
```lua
package = {
    spec = "1",
    name = "virtualbox",
    description = "Oracle VM VirtualBox (userspace + VBoxManage CLI)",
    homepage = "https://www.virtualbox.org",
    maintainers = {"Oracle"},
    licenses = {"GPL-3.0"},
    type = "package",
    archs = {"x86_64"},          -- macOS arm64 用单独 dmg 构建,hook 内按 host 选文件
    status = "stable",
    categories = {"virtualization", "vm", "hypervisor"},
    keywords = {"virtualbox", "vbox", "vm"},
    programs = {"VBoxManage", "VBoxHeadless", "VirtualBox"},
    xvm_enable = true,
    xpm = {
        windows = { ["latest"]={ref="7.2.8"}, ["7.2.8"]={ url="https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-Win.exe", sha256=nil } },
        linux   = { ["latest"]={ref="7.2.8"}, ["7.2.8"]={ url="https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-Linux_amd64.run", sha256=nil } },
        ubuntu  = { ref = "linux" },
        macosx  = { ["latest"]={ref="7.2.8"}, ["7.2.8"]={ url="https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-OSX.dmg", sha256=nil } },
    },
}
```

**hook 行为(解压式 + xvm 注册,驱动隔离)**
- `install()`:把用户态文件落到 `pkginfo.install_dir()`
  - **windows**:从 `Win.exe` 抽取 MSI 内容(`exe --extract -path <dir>` / `msiexec /a ... TARGETDIR=`),将 VirtualBox 目录解压进 install_dir(不跑系统安装器)。
  - **linux**:`.run` 解包(`sh VirtualBox-*.run --target <dir> --noexec` 或解出内含 tar),取用户态二进制到 install_dir。
  - **macosx**:`hdiutil attach` 挂载 dmg,从 pkg 抽取 `VirtualBox.app` 内的 `VBoxManage` 等到 install_dir。
- `config()`:
  1. `xvm.add("VBoxManage", { bindir = <install_dir>/<bin> })`,同理注册 `VBoxHeadless`、`VirtualBox`(GUI)。→ **命令闭环受 xlings 管理**。
  2. **内核驱动安装(唯一特权步,显式可检测)**:
     - linux:`sudo <install_dir>/...` 加载/构建 `vboxdrv`(需 `dkms`+`linux-headers`,作为 `xpm.linux.deps` 或 hook 内补齐);`sudo vboxreload`;`usermod -aG vboxusers $USER`。
     - windows:安装/加载 `VBoxDrv.sys` 等驱动(`VBoxDrvInst.exe`,需管理员);可借鉴 Portable-VirtualBox 的即插即用驱动加载思路。
     - macosx:触发并提示「系统设置→隐私与安全性」放行 Oracle kext(**交互,不可全静默**)。
  - 驱动步骤失败不阻断用户态注册:`VBoxManage` 仍可用于配置;仅"启动 VM"受影响,日志明确告知。
- `installed()`:优先 `VBoxManage --version`;回退检查 install_dir 内可执行文件存在。
- `uninstall()`:`xvm.remove("VBoxManage"...)`;卸载/卸驱动(`vboxdrv` 卸载脚本 / 驱动反注册);删 install_dir。

> 说明:这样做的好处是 `virtualbox` 成为**正常受管 package**(可 `xlings list`/多版本/xvm 路由),把不可避免的特权面缩到最小且显式。

### 4.2 `ubuntu-desktop-iso`(资源包,`type = "res"`)

**职责**:把 Ubuntu 24.04 desktop ISO 作为**受管资源**下载并缓存到 `pkginfo.install_dir()`,供 `virtualbox-ubuntu` 等通过依赖定位,不注册任何命令。

```lua
package = {
    spec = "1",
    name = "ubuntu-desktop-iso",
    description = "Resource: Ubuntu 24.04 Desktop installation ISO (amd64)",
    homepage = "https://ubuntu.com",
    licenses = {"various"},
    type = "res",                         -- 新类型(见 §2.3 / §7)
    archs = {"x86_64"},
    status = "stable",
    categories = {"resource", "iso", "ubuntu"},
    keywords = {"ubuntu", "24.04", "iso", "desktop", "res"},
    xpm = {
        linux = {
            ["latest"] = { ref = "24.04.4" },
            ["24.04.4"] = {
                url = {
                    GLOBAL = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso",
                    CN     = "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04/ubuntu-24.04.4-desktop-amd64.iso",
                },
                sha256 = "<待填:官方 SHA256SUMS>",
            },
        },
        windows = { ref = "linux" },
        macosx = { ref = "linux" },
    },
}
-- res 包:无需 xvm;install() 仅把 ISO 落到 install_dir(框架已下载),或留空让框架缓存。
function install() return true end
function uninstall() return true end
```
- 框架已支持 `url` 自动下载 + sha256 校验 → 资源完整性受管。
- ISO 较大,`installed()` 命中缓存即跳过,避免重复大流量下载。
- (决策:不单独出 `ubuntu-server-iso`,首批只做 desktop。)

### 4.3 `virtualbox-ubuntu`(编排包,`type = "package"`)

**职责**:依赖 `virtualbox` + `ubuntu-desktop-iso`,用 xvm 路由的 `VBoxManage` 无人值守建好一台 Ubuntu VM。所有逻辑走 `VBoxManage`,跨平台共用。

```lua
package = {
    spec = "1",
    name = "virtualbox-ubuntu",
    description = "Provision a ready-to-use Ubuntu 24.04 VM in VirtualBox (unattended)",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"virtualization", "vm", "ubuntu"},
    keywords = {"virtualbox", "ubuntu", "24.04", "unattended"},
    xvm_enable = true,           -- 可选注册一个 ubuntu-vm 启停命令
    xpm = {
        windows = { deps = {"virtualbox", "ubuntu-desktop-iso"}, ["latest"]={ref="24.04.4"}, ["24.04.4"]={} },
        linux   = { deps = {"virtualbox", "ubuntu-desktop-iso"}, ["latest"]={ref="24.04.4"}, ["24.04.4"]={} },
        ubuntu  = { ref = "linux" },
        macosx  = { deps = {"virtualbox", "ubuntu-desktop-iso"}, ["latest"]={ref="24.04.4"}, ["24.04.4"]={} },
    },
}
```

**ISO 定位(跨包)**:`pkginfo.dep_install_dir("ubuntu-desktop-iso")` → 取得 ISO 路径(范式见 `mcpp-vscode-clangd.lua` 用 `dep_install_dir("llvm-tools")`)。

**可配置项(环境变量带默认)**:`VBOX_UBUNTU_VM_NAME`(`ubuntu-24.04`)、`_CPUS`(2)、`_RAM_MB`(4096)、`_DISK_MB`(40000)、`_USER`/`_PASSWORD`(`xlings`/`xlings`)、`_HEADLESS`(true)。

**`install()` 流程**(全部经 xvm 路由的 `VBoxManage`):
```
1. 校验 VBoxManage --version 可用(否则提示先装 virtualbox)。
2. iso = dep_install_dir("ubuntu-desktop-iso") .. "/ubuntu-24.04.4-desktop-amd64.iso"
3. createvm --name $VM --ostype Ubuntu_64 --register
4. modifyvm $VM --cpus $CPUS --memory $RAM --vram 16 --nic1 nat
5. createmedium disk ... + storagectl SATA + storageattach hdd
6. unattended install $VM --iso=$iso --user --password --full-user-name
      --hostname ubuntu2404.local --install-additions [--start-vm=headless|gui]
7. 轮询 showvminfo 直至安装完成。
```
- `config()`(可选):注册便捷命令 `xvm.add("ubuntu-vm", {...})` 封装 start/stop/ssh(满足"有命令的注册到 xvm")。
- `installed()`:`VBoxManage list vms` 含 `"$VM"`。
- `uninstall()`:`controlvm $VM poweroff` → `unregistervm $VM --delete`;ISO 由 res 包管理,默认不删。

### 4.4 `virtualbox-extpack`(可选,`type = "package"`)

- deps `virtualbox`;三平台同一 `.vbox-extpack` 文件。
- `install()`:`VBoxManage extpack install --replace --accept-license=<sha256> <file>`。
- `uninstall()`:`VBoxManage extpack uninstall "Oracle VM VirtualBox Extension Pack"`。
- PUEL 许可:仅个人/教育/评估免费,包描述与日志明确告知。

---

## 5. xlings-res / 镜像策略

- VirtualBox 安装器(127~170M):官方直链,sha256 校验;后续按需评估镜像到 xlings-res。
- **Ubuntu ISO(3.2~6.2G):不进 xlings-res**,由 `res` 包用 `url={GLOBAL,CN}` 指向官方 + 清华镜像。
- 扩展包(20M):官方直链。

---

## 6. 风险与边界(必须在日志/文档明示)

| 风险 | 说明 | 处理 |
| -- | -- | -- |
| **内核驱动 = 不可绕过的特权步**(✅ 已认可) | 无 `vboxdrv` 则 VM 不能开机(用户态仍可配置) | 隔离到 `config()`,失败不阻断用户态注册,明确提示 |
| **Windows: Hyper-V/WSL2 冲突** | 本仓库已有 `wsl-ubuntu`;开启 Hyper-V 时 VBox 走兼容后端、性能降 | 检测并提示取舍 |
| **VT-x/AMD-V** | BIOS 未开则无法建 64 位 VM | 建 VM 前检测,给指引 |
| **Linux Secure Boot** | vbox 模块需签名 | 提示关闭或 MOK 签名 |
| **Linux 需内核头/DKMS** | 编译模块依赖 `linux-headers`/`gcc`/`make`/`dkms` | 声明 deps 或 hook 预装 |
| **macOS kext 放行** | 需用户手动允许,**不可全静默** | 文档/日志明示 |
| **`type=res` 框架支持未定** | 现仓库无先例 | §7 确认;回退 `package`+空 config |
| **ISO 大体积** | 3.2~6.2G | res 包缓存、命中跳过 |
| **CI 无法真跑 VM** | 容器无嵌套虚拟化 | 测试仅锁静态/契约 |

---

## 7. 待 review 的开放决策

已决策(✅):
- **内核驱动边界**:认可"用户态 xvm 闭环 + 驱动作为最小特权 config 步"。
- **ISO 粒度**:首批只做 `ubuntu-desktop-iso`,不出 `ubuntu-server-iso`。

仍待 review:
1. **`type = "res"` 是否被 xlings 框架支持?** 若暂不支持,先用 `type="package"`+空 `config()` 落地,待框架支持再切 `res`。(需你确认框架现状。)
2. **默认客户机账号/密码**:`xlings/xlings` + 强提示改密,可否?
3. **Windows 解压式 vs 官方安装器**:倾向**抽取 MSI 解压式**(更闭环);若抽取驱动注册过于脆弱,回退到官方静默安装器。接受这个回退策略吗?
4. **`virtualbox-ubuntu` 是否注册 `ubuntu-vm` 启停命令到 xvm**(满足"有命令注册 xvm")?
5. **(记录项)** 若以后想要"零特权纯用户态"闭环,可评估 QEMU 后端;本次仍以 VirtualBox 为主。

---

## 8. 落地与验证计划(review 通过后执行)

- [ ] `pkgs/v/virtualbox.lua` + `tests/v/test_virtualbox.py`
- [ ] `pkgs/u/ubuntu-desktop-iso.lua` + `tests/u/test_ubuntu_desktop_iso.py`
- [ ] `pkgs/v/virtualbox-ubuntu.lua` + `tests/v/test_virtualbox_ubuntu.py`
- [ ] (可选)`pkgs/v/virtualbox-extpack.lua` + 测试
- [ ] 测试锁定边界:import 仅 `xim.libxpkg.*`;`package` 包走解压 + `xvm.add(bindir)`;`res` 包不 `xvm.add`、仅资源契约。
- [ ] 本地真机(具备虚拟化)直跑:`xlings install virtualbox` → xvm 路由 `VBoxManage --version`;`xlings install virtualbox-ubuntu` → `VBoxManage list vms`;`xlings remove ...` 清理。
- [ ] pytest L0~L2(CI 不实跑 VM)。
- [ ] 补 sha256(安装器/ISO/extpack)后固化版本。
- [ ] PR 描述:作用 / 安装做了什么 / 卸载做了什么 / 是否改系统配置(内核驱动!)/ 测试结果。

---

## 来源
- VirtualBox 7.2.8 下载目录: https://download.virtualbox.org/virtualbox/7.2.8/
- VirtualBox 安装/驱动说明(vboxdrv 必要性): https://www.virtualbox.org/manual/ch02.html
- VBoxManage unattended: https://www.virtualbox.org/manual/topics/vboxmanage.html#vboxmanage-unattended
- Ubuntu 24.04 releases: https://releases.ubuntu.com/24.04/
- 仓库内范式: `pkgs/c/cmake.lua`(解压+xvm bindir)、`pkgs/m/mcpp-vscode-clangd.lua`(dep_install_dir)、`pkgs/w/wsl-ubuntu.lua`、`pkgs/r/ros2-jazzy-ubuntu.lua`
