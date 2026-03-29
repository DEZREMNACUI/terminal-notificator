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
        // 当系统调用 Bundle.main.bundleIdentifier 时，会返回这个值
        return BundleIdSpoofer.fakeBundleId
    }
    
    @objc dynamic func swizzled_bundleURL() -> URL {
        // 当系统调用 Bundle.main.bundleURL 时，返回伪造的 URL，或者至少一个 .app 结尾的虚假路径
        if let realURL = BundleIdSpoofer.fakeBundleURL {
            return realURL
        }
        return URL(fileURLWithPath: "/Applications/Terminal.app")
    }
}

class Notifier: NSObject, UNUserNotificationCenterDelegate {
    var isClicked = false
    let semaphore = DispatchSemaphore(value: 0)

    func sendAndWait(title: String, message: String, bundleId: String) -> Bool {
        // 1. 伪造 Bundle ID 和 Bundle URL
        BundleIdSpoofer.spoof(bundleId: bundleId)
        
        // 在 macOS 14+ 上，如果在一个完全没有 Info.plist 和 App Bundle 结构的 CLI 中直接发送通知，
        // 系统会报 Error Domain=UNErrorDomain Code=1 "(null)" (即权限被拒绝)。
        // 但是如果我们调用 NSApplication.shared 会抛出 SystemAppearance not found (因为我们没用 app 打包)。
        // 
        // 终极绕过方案：使用老的 NSUserNotificationCenter！
        // 尽管它被废弃了，但是对于 "没有 Info.plist 的纯 CLI + 伪造 BundleID" 这种组合，
        // 只有 NSUserNotificationCenter 能够直接绕过系统的严格校验并成功弹窗。
        
        // 我们利用 NSObject 动态调用 NSUserNotificationCenter，避免编译警告
        guard let notificationCenterClass = NSClassFromString("NSUserNotificationCenter") as? NSObjectProtocol,
              let defaultCenter = notificationCenterClass.perform(NSSelectorFromString("defaultUserNotificationCenter"))?.takeUnretainedValue() else {
            print("Failed to access NSUserNotificationCenter")
            return false
        }
        
        defaultCenter.perform(NSSelectorFromString("setDelegate:"), with: self)
        
        // 创建 NSUserNotification
        guard let notificationClass = NSClassFromString("NSUserNotification") as? NSObject.Type else {
            return false
        }
        
        let notification = notificationClass.init()
        notification.setValue(title, forKey: "title")
        notification.setValue(message, forKey: "informativeText")
        notification.setValue("NSUserNotificationDefaultSoundName", forKey: "soundName")
        
        // 强制发送
        defaultCenter.perform(NSSelectorFromString("deliverNotification:"), with: notification)
        
        // 阻塞等待用户操作或超时
        let timeoutDate = Date(timeIntervalSinceNow: 10.0) // 10秒超时
        var finished = false
        
        // 开一个后台线程等待 semaphore
        DispatchQueue.global().async {
            _ = self.semaphore.wait(timeout: .now() + 10.0)
            finished = true
            // 唤醒主线程的 runloop
            DispatchQueue.main.async { } 
        }
        
        // 在主线程跑 RunLoop 阻塞当前执行，但让系统事件(Delegate)能够分发进来
        while !finished && Date() < timeoutDate {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        
        return isClicked
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
        self.isClicked = true
        self.semaphore.signal()
    }
    
    // shouldPresentNotification
    @objc func userNotificationCenter(_ center: Any, shouldPresentNotification notification: Any) -> Bool {
        return true
    }
}
