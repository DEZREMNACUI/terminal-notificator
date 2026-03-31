import Foundation
@preconcurrency import ObjectiveC
import ArgumentParser
import AppKit

@main
struct TerminalNotificatorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "terminal-notificator",
        abstract: "A lightweight macOS CLI notification tool that wakes up your terminal.",
        version: "2.0.0"
    )

    @Option(name: .shortAndLong, help: "Notification title. Default: terminal app name.")
    var title: String?

    @Option(name: .shortAndLong, help: "Notification message body. Default: current directory.")
    var message: String?

    @Flag(name: .shortAndLong, help: "Enable verbose mode for debugging.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Always show notification even if terminal is focused.")
    var alwaysShow: Bool = false

    @Option(name: .long, help: "Timeout in seconds to wait for notification click or window focus. Default: 3600 seconds (1 hour).")
    var timeout: Int?

    mutating func run() throws {
        let isVerbose = self.verbose
        let alwaysShow = self.alwaysShow
        let titleArg = self.title
        let messageArg = self.message
        let timeoutSeconds = self.timeout ?? 3600  // 默认 1 小时

        Task { @MainActor in
            do {
                if isVerbose {
                    print("[INFO] Searching for parent terminal context...")
                }

                let context = try await TerminalContext.detect()
                let targetBundleId = context.bundleId

                // 使用默认值：title = 应用名，message = 当前目录
                let notificationTitle = titleArg ?? context.appName
                let notificationMessage = messageArg ?? context.currentDirectory

                if isVerbose {
                    print("[INFO] Identified Terminal:")
                    print("       Name: \(context.appName)")
                    print("       Bundle ID: \(targetBundleId)")
                    print("       PID: \(context.appPid)")
                    print("       Directory: \(context.currentDirectory)")
                    print("       Timeout: \(timeoutSeconds) seconds")
                }

                // 检查是否需要跳过
                if !alwaysShow {
                    let isFocused = await context.isFrontmostAndActive()
                    if isFocused {
                        if isVerbose {
                            print("[INFO] Terminal window is currently focused, skipping notification.")
                        }
                        Darwin.exit(0)
                    }
                }

                let service = NotificationService()
                if isVerbose {
                    print("[INFO] Sending notification as \(targetBundleId)...")
                }

                // 使用 TaskGroup 同时监控：通知点击、窗口焦点、超时
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // 任务1: 发送通知并等待点击
                    group.addTask {
                        let response = try await service.sendNotification(
                            title: notificationTitle,
                            message: notificationMessage,
                            context: context
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
                    }

                    // 任务2: 使用 NSWorkspace 通知监控窗口焦点
                    group.addTask {
                        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                            final class State: @unchecked Sendable {
                                var didResume = false
                            }
                            let state = State()
                            let _ = NotificationCenter.default.addObserver(
                                forName: NSWorkspace.didActivateApplicationNotification,
                                object: nil,
                                queue: .main
                            ) { notification in
                                guard !state.didResume else { return }
                                
                                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                                    return
                                }

                                // 检查是否是目标应用
                                guard app.bundleIdentifier == context.bundleId,
                                      app.processIdentifier == context.appPid else {
                                    return
                                }

                                // 检查窗口是否匹配目录（对于支持的终端）
                                Task {
                                    let isFocused = await context.isFrontmostAndActive()
                                    if isFocused && !state.didResume {
                                        state.didResume = true
                                        if isVerbose {
                                            print("[INFO] Terminal window focused, removing notification and exiting.")
                                        }
                                        await service.removeNotification()
                                        continuation.resume()
                                        Darwin.exit(0)
                                    }
                                }
                            }
                        }
                    }

                    // 任务3: 超时
                    group.addTask {
                        try? await Task.sleep(for: .seconds(timeoutSeconds))
                        if isVerbose {
                            print("[INFO] Timeout reached, exiting.")
                        }
                        await service.removeNotification()
                        Darwin.exit(0)
                    }

                    // 等待第一个任务完成
                    _ = try await group.next()
                    group.cancelAll()
                }

                Darwin.exit(0)
            } catch {
                print("[ERROR] \(error.localizedDescription)")
                Darwin.exit(1)
            }
        }

        // 保持主线程运行直到异步任务完成
        RunLoop.main.run(until: Date(timeIntervalSinceNow: Double(timeoutSeconds) + 5))
    }
}
