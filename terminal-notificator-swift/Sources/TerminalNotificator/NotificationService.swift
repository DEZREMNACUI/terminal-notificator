import Foundation

struct NotificationService {
    private let notificationManager = NotificationManager()

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
