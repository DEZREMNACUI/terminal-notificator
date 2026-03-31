import Foundation
@preconcurrency import UserNotifications
import AppKit

actor NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var continuation: CheckedContinuation<Bool, Error>?
    private var notificationCenter: UNUserNotificationCenter?
    private var currentNotificationId: String?

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await setIsClicked(true)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .list]
    }

    // MARK: - Public API

    /// 发送 OSC 9 通知（适用于 Ghostty 等终端）
    /// 直接输出到 /dev/tty 以绕过 stdout 重定向
    func sendOSC9(title: String) {
        let osc9 = "\u{1B}]9;\(title)\u{1B}\\"

        // 优先写入 /dev/tty，确保即使 stdout 被重定向也能生效
        if let tty = FileHandle(forWritingAtPath: "/dev/tty") {
            tty.write(Data(osc9.utf8))
            try? tty.close()
        } else {
            // 回退到 stdout
            print(osc9, terminator: "")
            fflush(stdout)
        }
    }

    /// 发送系统通知，返回是否被点击
    func send(title: String, message: String) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        self.notificationCenter = center
        center.delegate = self

        let notificationId = UUID().uuidString
        self.currentNotificationId = notificationId

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    Task { await self.resume(with: .failure(error)) }
                    return
                }

                guard granted else {
                    Task { await self.resume(with: .failure(NotificationError.permissionDenied)) }
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default

                let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
                center.add(request) { error in
                    if let error = error {
                        Task { await self.resume(with: .failure(error)) }
                    }
                }
            }
        }
    }

    func removeNotification() {
        guard let currentNotificationId, let notificationCenter else { return }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [currentNotificationId])
        self.currentNotificationId = nil
    }

    // MARK: - Private

    private func setIsClicked(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    private func resume(with result: Result<Bool, Error>) {
        guard let continuation else { return }
        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
        self.continuation = nil
    }
}
