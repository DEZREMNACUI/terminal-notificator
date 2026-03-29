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
    private var notificationCenter: UNUserNotificationCenter?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await setIsClicked(true)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .list]
    }

    private func setIsClicked(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    func send(title: String, message: String, bundleId: String) async throws -> Bool {
        // 1. 先用 .app 自己的 bundle ID 请求通知权限
        let center = UNUserNotificationCenter.current()
        self.notificationCenter = center
        center.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // 请求授权（使用 .app 自己的 bundle ID）
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    Task {
                        await self.resumeContinuation(with: .failure(error))
                    }
                    return
                }

                if !granted {
                    Task {
                        await self.resumeContinuation(with: .failure(NotificationError.permissionDenied))
                    }
                    return
                }

                // 2. 权限获得后，伪造 Bundle ID 以让通知显示为终端应用
                BundleIdSpoofer.spoof(bundleId: bundleId)

                // 3. 创建并发送通知
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

                center.add(request) { error in
                    if let error = error {
                        Task {
                            await self.resumeContinuation(with: .failure(error))
                        }
                        return
                    }

                    // 通知已添加，设置超时
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
                        await self.clearContinuationIfNeeded()
                    }
                }
            }
        }
    }

    private func resumeContinuation(with result: Result<Bool, Error>) {
        if let continuation = continuation {
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
            self.continuation = nil
        }
    }

    private func clearContinuationIfNeeded() {
        if let continuation = continuation {
            continuation.resume(returning: false)
            self.continuation = nil
        }
    }
}
