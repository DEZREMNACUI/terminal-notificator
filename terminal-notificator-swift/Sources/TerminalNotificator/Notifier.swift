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
    private var continuation: CheckedContinuation<Bool, Never>?

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

    override func responds(to aSelector: Selector!) -> Bool {
        let selName = NSStringFromSelector(aSelector)
        if selName == "userNotificationCenter:didActivateNotification:" ||
           selName == "userNotificationCenter:shouldPresentNotification:" {
            return true
        }
        return super.responds(to: aSelector)
    }

    // didActivateNotification
    @objc func userNotificationCenter(_ center: Any, didActivateNotification notification: Any) {
        Task {
            await setIsClicked(true)
        }
    }

    // shouldPresentNotification
    @objc func userNotificationCenter(_ center: Any, shouldPresentNotification notification: Any) -> Bool {
        return true
    }
}
