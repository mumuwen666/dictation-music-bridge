# 听写音乐联动

[English](README.en.md)

macOS 菜单栏工具。开始使用系统听写时暂停网易云音乐，结束或取消听写后从原位置续播。听写前已暂停的音乐会保持暂停。

## 从源码安装

构建目标为 macOS 14.4 或更高版本。已在 macOS 26.6.2 和网易云音乐桌面版 3.0.19 上验证。若尚未安装 Xcode 命令行工具，请先运行 `xcode-select --install`。

在项目目录运行以下命令，构建并打开应用。

```bash
bash build.sh "$HOME/Applications/听写音乐联动.app"
open "$HOME/Applications/听写音乐联动.app"
```

1. 点击菜单栏里的波形图标，选择「授予辅助功能权限」，然后在「系统设置 → 隐私与安全性 → 辅助功能」打开「听写音乐联动」。
2. 确认「系统设置 → 键盘 → 听写」已开启。播放一首歌，用平时的快捷键开始听写，然后结束听写，即可验证暂停和续播。
3. 如需自动运行，在波形菜单勾选「登录时启动」。

卸载前先取消「登录时启动」并退出应用，再把应用移到废纸篓。

## 构建与分发

`bash build.sh` 为当前 Mac 的架构构建，`bash build.sh --universal` 同时构建 Apple 芯片和 Intel 版本。默认产物是 `dist/听写音乐联动.app`。也可传入一个尚不存在的绝对 `.app` 路径。

默认构建使用临时签名，适合本机运行。分发预编译应用时，可用 `SIGN_IDENTITY='Developer ID Application: …'` 构建带强化运行时的签名版本，再提交 Apple 公证。[Apple 公证指南](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## 隐私与兼容性

工具监听 macOS 自带听写的开始和结束通知，通过辅助功能操作网易云音乐的「控制」菜单。它在本机处理事件，必要时读取系统听写进程的麦克风活动状态。所需权限只有辅助功能。

联动依赖 macOS 未公开的听写通知和网易云音乐的菜单文字。系统或播放器更新后可能需要适配。

采用 [MIT 许可证](LICENSE)。
