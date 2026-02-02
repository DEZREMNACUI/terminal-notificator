# Product Guidelines

## CLI UX Principles
- **快速响应 (Speed First)**: CLI 必须在启动后极短的时间内完成通知发送。任何涉及耗时操作（如查询父进程信息）的代码必须经过优化。
- **标准交互 (Standard Interface)**: 遵循 POSIX/GNU 命令行习惯。使用 `clap` 或类似的 Rust 库来提供一致的 `--help` 和参数解析体验。
- **清晰的错误反馈**: 虽然是后台工具，但当发生权限问题、API 失败或环境不兼容时，应提供详细的诊断信息 (Error Context)，而不仅仅是返回一个非零状态码。

## Notification Content Guidelines
- **完整呈现 (No Hidden Content)**: 默认情况下，不对用户输入的标题和消息内容进行主动截断。如果文本超过系统限制，交由 macOS 系统 UI 进行默认处理（如省略号），而非在应用层截断。
- **输入鲁棒性**: 能够处理包含 Unicode、表情符号 (Emoji) 以及简单特殊字符的字符串。

## Visual Identity & Branding
- **发送者标识 (Sender Identity)**: 
    - 默认名称为 "Terminal Notificator"。
    - 优先尝试在通知中展示发起请求的终端应用（如 Cursor, Warp）的特征，以建立通知与操作上下文的直觉联系。
- **图标策略**: 默认使用一个简洁的终端/通知相关的图标，或者根据上下文动态关联图标。

## Technical Excellence
- **零依赖运行时**: 构建静态链接的二进制文件，确保在没有安装 Rust 运行环境的 macOS 上也能直接运行。
- **macOS 原生集成**: 优先使用 macOS 原生的 UserNotifications 框架或 NSNotificationCenter（取决于兼容性要求），避免调用外部进程（如 `osascript`）以保证启动速度。
