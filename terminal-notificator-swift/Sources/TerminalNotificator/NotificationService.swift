import Foundation

struct NotificationService {
    private let notificationManager = NotificationManager()

    func sendNotification(
        title: String,
        message: String,
        context: TerminalContext,
        timeout: Duration = .seconds(10)
    ) async throws -> NotificationResponse {
        let wasClicked = try await withThrowingTaskGroup(of: Bool.self) { group in
            // 主任务：发送通知
            group.addTask {
                try await notificationManager.send(title: title, message: message, bundleId: context.bundleId)
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
            activationSuccess = await context.activate()
        }

        return NotificationResponse(wasClicked: wasClicked, activationSuccess: activationSuccess)
    }
}
