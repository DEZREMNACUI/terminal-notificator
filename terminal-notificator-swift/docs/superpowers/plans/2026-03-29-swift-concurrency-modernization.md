# Swift 并发模型现代化改造实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 terminal-notificator-swift 从传统 GCD 并发模型彻底重写为现代 Swift async/await 并发模型

**Architecture:** 采用分层架构 - 命令层 → 服务层 → 通知层 → 上下文层，所有并发操作使用 async/await，actor 保护共享状态

**Tech Stack:** Swift 5.9+, Swift Concurrency (async/await/actor), macOS 15+

---

### Task 1: 更新 Package.swift 平台要求

**Files:**
- Modify: `Package.swift`

- [x] **Step 1: 更新平台版本要求**

修改 `Package.swift`，将平台版本从 macOS 11 提升到 macOS 15（使用字符串格式以兼容旧版 tools）：

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerminalNotificator",
    platforms: [
        .macOS("15.0")
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TerminalNotificator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)
```

- [x] **Step 2: 验证 Package.swift 可以正常解析**

Run: `swift package resolve`
Expected: 成功解析依赖，无错误

- [x] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "chore: 提升最低平台版本到 macOS 15"
```

---

### Task 2: 创建 NotificationError 错误类型

**Files:**
- Create: `Sources/TerminalNotificator/NotificationError.swift`

- [x] **Step 1: 创建 NotificationError.swift 文件**

```swift
import Foundation

enum NotificationError: Error {
    case notificationCenterUnavailable
    case failedToDeliverNotification
    case timeout
    case activationFailed
    case bundleSpoofingFailed
    case terminalContextNotFound
}

extension NotificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notificationCenterUnavailable:
            return "通知中心不可用"
        case .failedToDeliverNotification:
            return "发送通知失败"
        case .timeout:
            return "操作超时"
        case .activationFailed:
            return "激活终端失败"
        case .bundleSpoofingFailed:
            return "Bundle ID 伪造失败"
        case .terminalContextNotFound:
            return "无法检测终端上下文"
        }
    }
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/NotificationError.swift
git commit -m "feat: 添加 NotificationError 错误类型"
```

---

### Task 3: 创建 NotificationResponse 响应类型

**Files:**
- Create: `Sources/TerminalNotificator/NotificationResponse.swift`

- [x] **Step 1: 创建 NotificationResponse.swift 文件**

```swift
import Foundation

struct NotificationResponse {
    let wasClicked: Bool
    let activationSuccess: Bool?
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/NotificationResponse.swift
git commit -m "feat: 添加 NotificationResponse 响应类型"
```

---

### Task 4: 重写 TerminalContext 为并发版本

**Files:**
- Modify: `Sources/TerminalNotificator/Context.swift`

- [x] **Step 1: 重写 Context.swift**

完全替换文件内容为（注意：`activate` 方法使用空 options 替代已废弃的 `.activateIgnoringOtherApps`）：

```swift
import Foundation
import AppKit

struct TerminalContext {
    let bundleId: String
    let appName: String
    let appPid: pid_t

    @MainActor
    static func detect() async throws -> TerminalContext {
        // 1. 尝试从环境变量获取
        if let context = try await getTerminalFromEnv() {
            return context
        }

        // 2. 如果环境变量没有，通过进程树查找
        let ppid = getppid()
        if let context = try await resolveAppInfo(startingPid: ppid) {
            return context
        }

        throw NotificationError.terminalContextNotFound
    }

    @MainActor
    func activate() async -> Bool {
        // 先尝试用 AppleScript 激活特定窗口
        if await activateViaAppleScript(pid: appPid) {
            return true
        }

        // 回退到用 NSWorkspace 激活整个应用
        if let app = NSRunningApplication(processIdentifier: appPid) {
            return app.activate(options: [])
        }

        return false
    }
}

// MARK: - Helper Functions

@MainActor
private func getTerminalFromEnv() async -> TerminalContext? {
    guard let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"] else {
        return nil
    }

    let mapping: [String: (String, String)] = [
        "zed": ("dev.zed.Zed", "Zed"),
        "ghostty": ("com.mitchellh.ghostty", "Ghostty"),
        "apple_terminal": ("com.apple.Terminal", "Terminal"),
        "iterm.app": ("com.googlecode.iterm2", "iTerm")
    ]

    guard let (bundleId, appName) = mapping[termProgram.lowercased()] else {
        return nil
    }

    if let pid = await findTerminalPid(bundleId: bundleId) {
        return TerminalContext(bundleId: bundleId, appName: appName, appPid: pid)
    }

    return nil
}

@MainActor
private func findTerminalPid(bundleId: String) async -> pid_t? {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications
    for app in apps {
        if app.bundleIdentifier == bundleId {
            return app.processIdentifier
        }
    }
    return nil
}

@MainActor
private func resolveAppInfo(startingPid: pid_t) async throws -> TerminalContext? {
    var currentPid = startingPid

    while currentPid > 1 {
        if let app = NSRunningApplication(processIdentifier: currentPid) {
            let procName = app.localizedName ?? ""
            let lowerName = procName.lowercased()

            if let bundleId = app.bundleIdentifier {
                if !lowerName.contains("helper") &&
                   !lowerName.contains("zsh") &&
                   !lowerName.contains("bash") &&
                   !lowerName.contains("login") {
                    return TerminalContext(bundleId: bundleId, appName: procName, appPid: currentPid)
                }
            }
        }

        // 获取父进程 PID
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        if result == 0 {
            currentPid = info.kp_eproc.e_ppid
        } else {
            break
        }
    }

    return nil
}

private func activateViaAppleScript(pid: pid_t) async -> Bool {
    let currentDir = FileManager.default.currentDirectoryPath
    let dirName = (currentDir as NSString).lastPathComponent

    let script = """
    tell application "System Events"
        try
            set targetProc to first process whose unix id is \(pid)
            tell targetProc
                set targetWin to (first window whose name contains "\(dirName)")
                perform action "AXRaise" of targetWin
                set frontmost to true
                return "true"
            end tell
        on error
            return "false"
        end try
    end tell
    """

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return output == "true"
        }
    } catch {
        print("Error running osascript: \(error)")
    }

    return false
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/Context.swift
git commit -m "refactor: 重写 TerminalContext 为并发版本"
```

---

### Task 5: 创建 NotificationManager actor

**Files:**
- Modify: `Sources/TerminalNotificator/Notifier.swift`

- [x] **Step 1: 完全重写 Notifier.swift 为 NotificationManager**

注意：@objc 方法需要添加 `nonisolated` 关键字，continuation 类型从 `CheckedContinuation<Bool, Never>` 改为 `CheckedContinuation<Bool, Error>`：

```swift
import Foundation
import UserNotifications
import AppKit

/// 这是一个黑魔法类，用于拦截 Bundle 的 bundleIdentifier 属性，
/// 从而让纯命令行工具能够欺骗 macOS 的 UNUserNotificationCenter。
class BundleIdSpoofer {
    static var fakeBundleId: String = "com.apple.Terminal"
    static var fakeBundleURL: URL?

    static func spoof(bundleId: String) {
        self.fakeBundleId = bundleId

        // 尝试找到对应 bundleId 的实际应用路径，用来伪造 bundleURL
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            self.fakeBundleURL = url
        }

        let bundleClass: AnyClass = Bundle.self

        // 拦截 bundleIdentifier
        if let originalMethod = class_getInstanceMethod(bundleClass, #selector(getter: Bundle.bundleIdentifier)),
           let swizzledMethod = class_getInstanceMethod(BundleIdSpoofer.self, #selector(swizzled_bundleIdentifier)) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        // 拦截 bundleURL (修复 macOS 14+ 上的 bundleProxyForCurrentProcess is nil 崩溃)
        if let originalUrlMethod = class_getInstanceMethod(bundleClass, #selector(getter: Bundle.bundleURL)),
           let swizzledUrlMethod = class_getInstanceMethod(BundleIdSpoofer.self, #selector(swizzled_bundleURL)) {
            method_exchangeImplementations(originalUrlMethod, swizzledUrlMethod)
        }
    }

    @objc dynamic func swizzled_bundleIdentifier() -> String? {
        return BundleIdSpoofer.fakeBundleId
    }

    @objc dynamic func swizzled_bundleURL() -> URL {
        if let realURL = BundleIdSpoofer.fakeBundleURL {
            return realURL
        }
        return URL(fileURLWithPath: "/Applications/Terminal.app")
    }
}

actor NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var continuation: CheckedContinuation<Bool, Error>?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didActivate response: UNNotificationResponse) {
        Task {
            await setIsClicked(true)
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    private func setIsClicked(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    func send(title: String, message: String, bundleId: String) async throws -> Bool {
        // 1. 伪造 Bundle ID 和 Bundle URL
        BundleIdSpoofer.spoof(bundleId: bundleId)

        // 使用 NSUserNotificationCenter（已废弃但仍可用）
        guard let notificationCenterClass = NSClassFromString("NSUserNotificationCenter") as? NSObjectProtocol,
              let defaultCenter = notificationCenterClass.perform(NSSelectorFromString("defaultUserNotificationCenter"))?.takeUnretainedValue() else {
            throw NotificationError.notificationCenterUnavailable
        }

        defaultCenter.perform(NSSelectorFromString("setDelegate:"), with: self)

        // 创建 NSUserNotification
        guard let notificationClass = NSClassFromString("NSUserNotification") as? NSObject.Type else {
            throw NotificationError.failedToDeliverNotification
        }

        let notification = notificationClass.init()
        notification.setValue(title, forKey: "title")
        notification.setValue(message, forKey: "informativeText")
        notification.setValue("NSUserNotificationDefaultSoundName", forKey: "soundName")

        // 使用 withCheckedContinuation 等待用户响应
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // 强制发送
            defaultCenter.perform(NSSelectorFromString("deliverNotification:"), with: notification)

            // 设置超时清理
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
                await self.clearContinuationIfNeeded()
            }
        }
    }

    private func clearContinuationIfNeeded() {
        if let continuation = continuation {
            continuation.resume(returning: false)
            self.continuation = nil
        }
    }

    // MARK: - NSUserNotificationCenterDelegate (动态实现)

    override nonisolated func responds(to aSelector: Selector!) -> Bool {
        let selName = NSStringFromSelector(aSelector)
        if selName == "userNotificationCenter:didActivateNotification:" ||
           selName == "userNotificationCenter:shouldPresentNotification:" {
            return true
        }
        return super.responds(to: aSelector)
    }

    // didActivateNotification
    @objc nonisolated func userNotificationCenter(_ center: Any, didActivateNotification notification: Any) {
        Task {
            await setIsClicked(true)
        }
    }

    // shouldPresentNotification
    @objc nonisolated func userNotificationCenter(_ center: Any, shouldPresentNotification notification: Any) -> Bool {
        return true
    }
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/Notifier.swift
git commit -m "refactor: 创建 NotificationManager actor"
```

---

### Task 6: 创建 NotificationService 业务逻辑层

**Files:**
- Create: `Sources/TerminalNotificator/NotificationService.swift`

- [x] **Step 1: 创建 NotificationService.swift 文件**

```swift
import Foundation

struct NotificationService {
    private let notificationManager = NotificationManager()

    func sendNotification(
        title: String,
        message: String,
        bundleId: String,
        timeout: Duration = .seconds(10)
    ) async throws -> NotificationResponse {
        let wasClicked = try await withThrowingTaskGroup(of: Bool.self) { group in
            // 主任务：发送通知
            group.addTask {
                try await notificationManager.send(title: title, message: message, bundleId: bundleId)
            }

            // 超时任务
            group.addTask {
                try await Task.sleep(for: timeout)
                throw NotificationError.timeout
            }

            // 等待第一个完成的任务
            guard let result = try await group.next() else {
                throw NotificationError.failedToDeliverNotification
            }

            // 取消其他任务
            group.cancelAll()

            return result
        }

        var activationSuccess: Bool?
        if wasClicked {
            let context = try await TerminalContext.detect()
            activationSuccess = await context.activate()
        }

        return NotificationResponse(wasClicked: wasClicked, activationSuccess: activationSuccess)
    }
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/NotificationService.swift
git commit -m "feat: 添加 NotificationService 业务逻辑层"
```

---

### Task 7: 重写命令层 TerminalNotificatorCommand

**Files:**
- Modify: `Sources/TerminalNotificator/TerminalNotificator.swift`

- [x] **Step 1: 重写 TerminalNotificator.swift**

完全替换文件内容为：

```swift
import Foundation
import ArgumentParser

@main
struct TerminalNotificatorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "terminal-notificator",
        abstract: "A lightweight macOS CLI notification tool that wakes up your terminal.",
        version: "2.0.0"
    )

    @Option(name: .shortAndLong, help: "Notification title.")
    var title: String = "Terminal Notificator"

    @Option(name: .shortAndLong, help: "Notification message body.")
    var message: String

    @Flag(name: .shortAndLong, help: "Enable verbose mode for debugging.")
    var verbose: Bool = false

    mutating func run() throws {
        let isVerbose = self.verbose
        let notificationTitle = self.title
        let notificationMessage = self.message

        Task { @MainActor in
            do {
                if isVerbose {
                    print("[INFO] Searching for parent terminal context...")
                }

                let context = try await TerminalContext.detect()
                let targetBundleId = context.bundleId

                if isVerbose {
                    print("[INFO] Identified Terminal:")
                    print("       Name: \(context.appName)")
                    print("       Bundle ID: \(targetBundleId)")
                    print("       PID: \(context.appPid)")
                }

                let service = NotificationService()
                if isVerbose {
                    print("[INFO] Sending notification as \(targetBundleId)...")
                }

                let response = try await service.sendNotification(
                    title: notificationTitle,
                    message: notificationMessage,
                    bundleId: targetBundleId,
                    timeout: .seconds(10)
                )

                if response.wasClicked {
                    if isVerbose {
                        print("[INFO] Notification clicked!")
                        if let success = response.activationSuccess {
                            print(success ? "[INFO] Terminal activated successfully." : "[INFO] Failed to activate terminal.")
                        }
                    }
                } else {
                    if isVerbose {
                        print("[INFO] Notification dismissed or expired.")
                    }
                }

                Darwin.exit(0)
            } catch {
                print("[ERROR] \(error.localizedDescription)")
                Darwin.exit(1)
            }
        }

        // 保持主线程运行直到异步任务完成
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 15))
    }
}
```

- [x] **Step 2: 验证代码可以编译**

Run: `swift build`
Expected: 编译成功

- [x] **Step 3: Commit**

```bash
git add Sources/TerminalNotificator/TerminalNotificator.swift
git commit -m "refactor: 重写命令层使用现代 Swift 并发"
```

---

### Task 8: 测试并验证完整功能

**Files:**
- Test: 所有文件

- [x] **Step 1: 构建完整项目**

Run: `swift build -c release`
Expected: 编译成功，无错误

- [x] **Step 2: 运行基本测试** (可选)

Run: `.build/release/terminal-notificator --title "测试" --message "这是一条测试通知" --verbose`
Expected: 发送通知，功能正常

- [x] **Step 3: 运行测试套件**

Run: `swift test`
Expected: 所有测试通过（如果有测试）

- [x] **Step 4: Commit**

```bash
git commit -m "test: 验证并发改造完成功能正常" --allow-empty
```

---

## 实现注意事项

本次实现中需要注意的关键调整：

1. **Package.swift**: 使用 `.macOS("15.0")` 字符串格式而不是 `.macOS(.v15)`，因为 Swift 5.9 tools 版本不支持 `.v15` 枚举

2. **NotificationManager actor**: 
   - `@objc` 方法需要添加 `nonisolated` 关键字才能从 actor 中暴露给 Objective-C 运行时
   - `continuation` 类型改为 `CheckedContinuation<Bool, Error>` 以配合 `withCheckedThrowingContinuation` 使用

3. **TerminalContext**: `activate()` 方法使用空 `options: []` 替代已在 macOS 14 中废弃的 `.activateIgnoringOtherApps`

---

## Self-Review

**1. Spec coverage:** 
- ✅ 平台要求: Task 1 更新到 macOS 15
- ✅ NotificationError: Task 2 实现
- ✅ NotificationResponse: Task 3 实现
- ✅ TerminalContext 并发版本: Task 4 实现
- ✅ NotificationManager actor: Task 5 实现
- ✅ NotificationService: Task 6 实现
- ✅ 命令层重写: Task 7 实现
- ✅ 测试验证: Task 8

**2. Placeholder scan:** 没有占位符，所有步骤都有完整代码

**3. Type consistency:** 所有类型定义和方法签名一致，NotificationError、NotificationResponse、TerminalContext、NotificationManager、NotificationService 都正确匹配
