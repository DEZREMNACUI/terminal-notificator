use mac_notification_sys::{Notification, set_application, NotificationResponse};

pub struct Notifier;

impl Notifier {
    pub fn new() -> Self {
        // let bundle_id = "com.apple.Terminal";
        // set_application(bundle_id).unwrap_or_default();
        Notifier
    }

    pub fn with_bundle_id(bundle_id: &str) -> Self {
        set_application(bundle_id).unwrap_or_default();
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