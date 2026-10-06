# 退出应用与深度清理 · macOS

退出当前用户的可见应用，保留终端相关进程，并清理用户缓存、日志、开发工具缓存和较旧的临时文件。

## 功能

- 保护当前脚本祖先进程与常见终端应用
- 明确列出可清理路径，显示实时进度
- 可选执行 pnpm store prune 和 Homebrew cleanup
- 汇总可用磁盘空间变化

## 使用

使用 macOS 内置 zsh 和系统命令；Homebrew、pnpm 为可选。无需 sudo。

```bash
chmod +x "一键退出并深度清理_v2.command"
./"一键退出并深度清理_v2.command" --help
./"一键退出并深度清理_v2.command" --dry-run
```

确认预览结果后，可双击 `.command` 文件或在终端不带参数执行。

## 清理范围

包含用户 Library/Caches、Library/Logs、应用 Cache / Code Cache / GPUCache、Xcode DerivedData、npm / Yarn / Gradle 缓存及当前用户 30 分钟以上的临时项目。重置 Quick Look 缩略图缓存；安装了相关工具时会整理 pnpm store 和 Homebrew 旧版本。

不以桌面、文稿、下载、照片、钥匙串、浏览器密码、书签、Cookie 或废纸篓为清理目标。缓存目录可能包含应用离线内容，清理后可能需要重新下载或重新构建；未保存工作应先保存。

`--dry-run` 只显示拟操作对象和统计，不退出应用、不删除内容、不调用工具清理。读取缓存大小可能需要一些时间。交互式运行结束后进入 zsh，终端窗口保持打开。

## 许可证

[MIT License](LICENSE)。
