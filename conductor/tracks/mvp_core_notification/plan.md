# 实施计划: MVP 核心通知与上下文切换

本计划概述了构建 MVP 的分步任务。所有代码更改必须遵循 TDD（测试驱动开发）流程。

## 阶段 1: 项目初始化与 CLI 基础 [checkpoint: f409fd9]

- [x] Task: 初始化 Rust 项目结构 fb1ef16
    - 创建 `Cargo.toml`。
    - 配置依赖 (`clap`, `sysinfo`, `objc2` 等)。
    - 设置基本的模块结构 (`main.rs`, `cli.rs`, `context.rs`, `notifier.rs`)。
- [x] Task: 实现命令行参数解析 41c707f
    - **TDD**: 编写测试用例验证 `-t`, `-m` 等参数的解析。
    - 实现 `cli` 模块，使用 `clap` 定义参数结构。
- [ ] Task: Conductor - 用户手册验证 '阶段 1: 项目初始化与 CLI 基础' (协议在 workflow.md)

## 阶段 2: 上下文感知与进程探测

- [x] Task: 实现父进程探测逻辑 333b67c
    - **TDD**: 编写测试（可能需要 mock `sysinfo`）来验证进程树查找逻辑。
    - 实现 `context` 模块，使用 `sysinfo` 获取当前进程的父进程 PID 和 Bundle ID。
    - 添加日志输出以方便调试（在 verbose 模式下）。
- [x] Task: 集成 macOS 窗口激活功能 (基础) c16f540
    - **TDD**: 这里的单元测试较难，侧重于封装原生调用的 unsafe 代码，并提供 safe 接口。
    - 使用 `objc2` / `AppKit` 实现根据 Bundle ID 激活应用的功能。
    - 编写一个简单的独立验证脚本 (`verify_focus.rs`) 来手动测试焦点切换。
- [ ] Task: Conductor - 用户手册验证 '阶段 2: 上下文感知与进程探测' (协议在 workflow.md)

## 阶段 3: 通知发送与交互

- [ ] Task: 实现 macOS 通知发送
    - **TDD**: 封装通知发送逻辑。
    - 使用 `UserNotifications` 框架发送简单的通知。
    - 确保支持标题和正文。
- [ ] Task: 实现通知点击回调与跳转集成
    - **TDD**: 模拟通知中心的回调逻辑（如果可能），或重点测试回调处理函数的逻辑。
    - 将“点击通知”事件与“激活父进程窗口”逻辑绑定。
    - 确保主线程保持运行直到通知被处理或超时。
- [ ] Task: Conductor - 用户手册验证 '阶段 3: 通知发送与交互' (协议在 workflow.md)

## 阶段 4: 构建与发布准备

- [ ] Task: 优化构建配置
    - 配置 release profile (LTO, strip symbols) 以减小体积。
    - 验证静态链接（确保不依赖非系统动态库）。
- [ ] Task: 编写最终验证脚本
    - 创建一个 shell 脚本，模拟“耗时任务完成 -> 弹出通知 -> 用户点击 -> 回到终端”的完整流程。
- [ ] Task: 完善文档
    - 更新 `README.md`，包含安装和使用说明。
- [ ] Task: Conductor - 用户手册验证 '阶段 4: 构建与发布准备' (协议在 workflow.md)
