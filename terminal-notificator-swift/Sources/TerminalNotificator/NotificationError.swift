import Foundation

enum NotificationError: Error {
    case notificationCenterUnavailable
    case failedToDeliverNotification
    case timeout
    case activationFailed
    case bundleSpoofingFailed
    case terminalContextNotFound
    case permissionDenied
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
        case .permissionDenied:
            return "通知权限被拒绝，请在系统设置中允许通知"
        }
    }
}
