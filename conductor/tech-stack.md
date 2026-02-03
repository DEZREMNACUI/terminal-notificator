# Tech Stack

## Core Language
- **Rust**: 作为核心开发语言。利用其零成本抽象、内存安全和高性能特性，确保 CLI 工具能够瞬间启动并瞬间启动并稳定运行。

## CLI Framework
- **Clap (v4)**: 用于处理命令行参数解析。支持生成的帮助信息、自动补全脚本以及类型安全的参数定义。

## macOS System Integration
- **mac-notification-sys**: 用于在 CLI 环境下稳健地发送 macOS 原生通知。它封装了对 `UserNotifications` 框架的调用，并妥善处理了 CLI 进程缺乏 Bundle ID 的限制。
- **Core Foundation / AppKit**: 用于检索进程信息、获取父进程的 Bundle ID 以及执行窗口激活（跳转）操作。

## Process & System Info
- **sysinfo**: 用于跨平台（此处主要为 macOS）地获取进程树信息，帮助精确定位发起通知的终端应用程序。

## Build & Distribution
- **Cargo**: Rust 的原生构建系统和包管理器。
- **Static Linking**: 默认采用静态链接，确保生成的二进制文件在没有 Rust 环境的 macOS 上也能独立运行。
