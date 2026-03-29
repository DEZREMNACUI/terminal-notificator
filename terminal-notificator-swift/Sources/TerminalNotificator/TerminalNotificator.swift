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

    @Flag(name: .shortAndLong, help: "Always show notification even if terminal is focused.")
    var alwaysShow: Bool = false

    mutating func run() throws {
        let isVerbose = self.verbose
        let notificationTitle = self.title
        let notificationMessage = self.message
        let alwaysShow = self.alwaysShow

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
                    print("       Directory: \(context.currentDirectory)")
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
