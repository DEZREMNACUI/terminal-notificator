use mac_notification_sys::{Notification, NotificationResponse};

pub struct Notifier;

impl Notifier {
    pub fn new() -> Self {
        Notifier
    }

    pub fn send_and_wait(&self, title: &str, message: &str) -> bool {
        let response = Notification::new()
            .title(title)
            .message(message)
            .wait_for_click(true)
            .send();

        match response {
            Ok(NotificationResponse::Click) | Ok(NotificationResponse::ActionButton(_)) => true,
            _ => false,
        }
    }
}
