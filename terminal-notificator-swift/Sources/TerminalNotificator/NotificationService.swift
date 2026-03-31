import Foundation

struct NotificationService {
    private let notificationManager = NotificationManager()

    /// 发送 OSC 9 通知（适用于 Ghostty 等终端）
    func sendOSC9Notification(title: String) {
        // OSC 9 格式: ESC ] 9 ; title ESC \
        let osc9 = "\u{1B}]9;\(title)\u{1B}\\"
        print(osc9, terminator: "")
        fflush(stdout)
    }

    func sendNotification(
        title: String,
        message: String,
        context: TerminalContext
    ) async throws -> NotificationResponse {
        let wasClicked = try await notificationManager.send(title: title, message: message, bundleId: context.bundleId)

        var activationSuccess: Bool?
        if wasClicked {
            activationSuccess = await context.activate()
        }

        return NotificationResponse(wasClicked: wasClicked, activationSuccess: activationSuccess)
    }

    func removeNotification() async {
        await notificationManager.removeNotification()
    }
}
