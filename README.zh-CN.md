# G710Keys

**让罗技 G710+ 的 G1–G6 键在现代 macOS 上真正可用。**

<img src="docs/icon-1024.png" width="160" alt="G710Keys 图标">

G710Keys 是一个菜单栏小工具（纯 Swift，无 kext），通过 USB HID 关掉键盘固件里
「G 键镜像成数字 1–6」的行为，然后把 G 键映射成任意按键、组合键或 shell 命令。

> 已在 macOS 26.7（Apple Silicon）+ G710+（`046D:C24D`）实测，理论支持 macOS 11+。

[English README](README.md)

## 为什么需要它

罗技在 macOS 上基本放弃了这个键盘：

* Mac 版 LGS 停在 **8.98.306（2018）**，32 位，仅支持 macOS 10.11–10.13；官方已宣布
  **2026-10-31 起下架所有 LGS 安装包和文档**。
* **G HUB** 根本不支持 G710+。
* **Karabiner-Elements** 单独用没用：G 键在**键盘固件**里被镜像成主键盘 1–6，Karabiner 只看到
  普通数字键，分不出来；而且用 Karabiner 接管这把键盘还会让 G 键/M 键和媒体键失效。
* 唯一的旧工具 [halo/g710plus](https://github.com/halo/g710plus) 已归档（Swift 3 时代），
  发布二进制也已失效。

G710Keys 是协议的现代重写版，并额外提供图形界面和「按键录制」。

## 功能

* **G1–G6 自定义**：默认 F13–F18，可改成任意键、⌘/⌃/⌥/⇧ 组合或 shell 命令
* **三档配置 M1/M2/M3**，并同步键盘上的 M 指示灯
* **录制**：点某行的「录制」，直接按想要的组合键（如 ⌘C）即可
* **长按重复**
* 菜单栏应用，无 Dock 图标
* 配置是普通 JSON：`~/Library/Application Support/G710Keys/config.json`

注意：**音量/播放等媒体键本来就能用**，G710Keys 不处理它们，只处理 G 键和 M 档位键。

## 编译

需要 Xcode Command Line Tools：

```bash
git clone https://github.com/jk8978/logitech-g710-macos.git
cd G710Keys
./scripts/build.sh      # 生成 build/G710Keys.app（ad-hoc 签名）
./scripts/install.sh    # 安装到 /Applications 并启动
```

## 权限（必须）

| 权限 | 用途 |
|---|---|
| **输入监控** | 读取 G 键的厂商 HID 报文 |
| **辅助功能** | 合成你映射的按键 |

到「系统设置 → 隐私与安全性 → 输入监控 / 辅助功能」勾选 **G710Keys**，然后退出重开 App
（窗口里有「授权后重启」按钮）。

> ⚠️ App 使用 **ad-hoc 签名**。重新编译/重新签名会改变代码签名，macOS 会让上面两个权限失效，
> 需要重新勾选一次。只改配置不受影响。

## 使用

1. 连接 G710+
2. 启动 G710Keys，菜单栏出现键盘图标，状态窗口打开
3. 选择要编辑的档位（M1/M2/M3 对应键盘上的 M 键）
4. 点 G 键右侧的「录制」按组合键，或手动输入：

   | 想要 | 填法 |
   |---|---|
   | F13 | `f13` |
   | ⌘⇧4 截图 | `cmd+shift+4` |
   | 打开 Safari | `shell:open -a Safari` |

5. 按键盘上的 G 键

支持的键名：`a`–`z`、`0`–`9`、`f1`–`f20`、`numpad0`–`numpad9`、方向键、
`home`/`end`/`pageup`/`pagedown`、`space`/`tab`/`return`/`escape`/`delete`/`forwarddelete`、
标点键（`minus`、`equal`、`comma`、`period`、`slash`、`semicolon`、`quote`、
`backslash`、`leftbracket`、`rightbracket`、`grave`）、
`numpadMultiply`/`numpadPlus`/`numpadMinus`/`numpadDivide`/`numpadDot`/`numpadEnter`。
修饰键：`cmd`、`ctrl`、`opt`、`shift`。

## 原理

G710+ 有两个 HID 接口（`046D:C24D`）：标准 6KRO 键盘（65 字节描述符）和 149 字节描述符
（NKRO 键盘 Report ID 1、Consumer 页 Report ID 2 = 媒体键、厂商页 `0xFF00` Report ID 3–9）。

固件默认把 G 键镜像到数字 1–6。App 发送一次 **Feature Report 9**（13 个零字节）关闭镜像，
然后监听厂商 **Report ID 3**：

```
byte 0: G1–G6 位图（bit0 … bit5）
byte 1: M1/M2/M3/MR（0x10/0x20/0x40/0x80）
byte 2: 背光 / 游戏模式位
```

匹配到映射后用 `CGEvent` 投递到 HID 事件流。

## 常见问题

* **G 键没反应**：检查两个权限是否绿色；刚授权要点「授权后重启」；看
  `~/Library/Logs/G710Keys.log`，按 G 键应有 `report rid=3 …`
* **媒体键失灵**：退出 Karabiner-Elements，或在它的 Devices 里取消 G710+
* **拔插键盘后 G 键又变成 1–6**：正常，镜像设置只在运行时有效，重开 App 即可
* **下载 release 提示「已损坏」**：ad-hoc 签名未公证，自己编译或运行
  `xattr -dr com.apple.quarantine /Applications/G710Keys.app`
* **MR 键**：G710+ 没有板载内存，LGS 的宏录制在电脑端完成，本项目暂不处理 MR

## 相关项目

* [Karabiner-Elements](https://karabiner-elements.pqrs.org/) — 普通键很好用，但这把键盘的 G 键它无能为力
* [g510-macos](https://github.com/paulloth1/g510-macos)、[G15Display](https://github.com/Tooker/G15Display) —
  其他型号，macOS HID + CGEvent 思路可参考
* Linux：[logiops](https://github.com/PixlOne/logiops)、
  [Wattos/logitech-g710-linux-driver](https://github.com/Wattos/logitech-g710-linux-driver)

## 致谢

G710+ 协议来自 [K900/g710](https://github.com/K900/g710) 与
[halo/g710plus](https://github.com/halo/g710plus) 的逆向工作，没有它们就没有这个项目。

## 免责声明

与罗技（Logitech）无任何关联。「Logitech」「G710+」「G-Series」是罗技的商标。使用风险自负。

## 许可

MIT，见 [LICENSE](LICENSE)。
