# Swift 并发模型现代化改造设计文档

**日期**: 2026-03-29
**项目**: Terminal Notificator
**作者**: TraeCli

## 概述

本文档描述了将 terminal-notificator-swift 项目从传统的 GCD (Grand Central Dispatch) 并发模型彻底重写为现代 Swift 并发模型 (async/await) 的设计方案。

## 目标

- 全面使用 Swift 新语法和新模型
- 代码现代化 - 使用 async/await
- 提高可维护性
- 为未来扩展做准备
- 全面重构包括代码结构优化

## 平台要求

- **最低 macOS 版本**: macOS 15+
- **Swift 版本**: 5.9+
- **利用完整的现代 Swift 并发 API

## 整体架构

```
TerminalNotificator
├── 命令层 (TerminalNotificatorCommand)
│   └── 解析参数 → 调用服务层
├── 服务层 (NotificationService)
│   ├── async send(title:message:bundleId:) -> NotificationResponse
│   └── 包含超时机制
├── 通知层 (NotificationManager)
│   └── 封装 UserNotifications 框架
└── 上下文层 (TerminalContext)
    └── async/await 版本的进程上下文检测
```

## 核心组件设计

### 1. NotificationError（错误类型）

```swift
enum NotificationError: Error {
    case notificationCenterUnavailable
    case failedToDeliverNotification
    case timeout
    case activationFailed
    case bundleSpoofingFailed
}
```

### 2. NotificationResponse（响应类型）

```swift
struct NotificationResponse {
    let wasClicked: Bool
    let activationSuccess: Bool?
}
```

### 3. NotificationManager（actor，封装通知逻辑）

```swift
actor NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?

    func send(title: String, message: String, bundleId: String) async throws -> Bool
}
```

### 4. TerminalContext（并发版本）

```swift
struct TerminalContext {
    let bundleId: String
    let appName: String
    let appPid: pid_t

    static func detect() async throws -> TerminalContext
    func activate() async -> Bool
}
```

### 5. NotificationService（业务逻辑层）

```swift
struct NotificationService {
    func sendNotification(
        title: String,
        message: String,
        timeout: Duration = .seconds(10)
    ) async throws -> NotificationResponse
}
```

## 数据流与并发模式

### 主要数据流

```
TerminalNotificatorCommand.run()
  ↓
Task { @MainActor in (因为需要 AppKit/NSWorkspace)
  ↓
TerminalContext.detect() async throws
  ↓
NotificationService.sendNotification() async throws
  ├─ 启动超时任务 (Task.timeout)
  ├─ NotificationManager.send() async throws
  │   ├─ BundleIdSpoofer.spoof()
  │   ├─ 发送通知
  │   └─ 等待用户点击 (withCheckedContinuation)
  └─ 如果点击 → TerminalContext.activate() async
  ↓
返回 NotificationResponse
}
```

### 关键并发技术

1. **MainActor**: AppKit 相关操作需要在主线程
2. **Task.timeout**: 替代原来的 DispatchQueue.asyncAfter
3. **withCheckedContinuation**: 桥接 delegate 回调到 async/await
4. **actor**: NotificationManager 作为 actor 保护共享状态

## 错误处理策略

- 使用 `throw` 和 `try/catch` 进行错误传播
- 每个错误都有明确的类型和上下文信息
- 命令层捕获错误并友好展示给用户

## 文件结构变化

### 现有文件
- `Package.swift` - 更新平台版本要求
- `Sources/TerminalNotificator/TerminalNotificator.swift` - 重写命令层
- `Sources/TerminalNotificator/Notifier.swift` - 完全重写为 NotificationManager actor
- `Sources/TerminalNotificator/Context.swift` - 重写为并发版本

### 新增文件
- `Sources/TerminalNotificator/NotificationError.swift` - 错误类型定义
- `Sources/TerminalNotificator/NotificationResponse.swift` - 响应类型定义
- `Sources/TerminalNotificator/NotificationService.swift` - 业务逻辑层

## 核心设计原则

- 所有并发操作都使用 `async/await`
- 使用 `actor` 来保护共享状态
- 使用 `Task` 和 `TaskGroup` 管理并发任务
- 使用 `withCheckedThrowingContinuation` 桥接 delegate 回调
- 自定义 `Error` 类型提供详细错误信息
