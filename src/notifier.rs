use mac_notification_sys::{Notification, set_application};

pub struct Notifier {
    bundle_id: String,
}

impl Notifier {
    pub fn new() -> Self {
        // Use a default bundle ID or try to use the parent's if available
        // Terminal.app is a safe default for notifications in CLI
        let bundle_id = "com.apple.Terminal".to_string();
        set_application(&bundle_id).unwrap_or_default();
        
        Notifier { bundle_id }
    }

    pub fn with_bundle_id(bundle_id: &str) -> Self {
        set_application(bundle_id).unwrap_or_default();
        Notifier { bundle_id: bundle_id.to_string() }
    }

    pub fn send(&self, title: &str, message: &str) -> bool {
        let response = Notification::new()
            .title(title)
            .message(message)
            .send();
            
        response.is_ok()
    }
}