import Foundation
import ArgumentParser

@main
struct TerminalNotificatorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "terminal-notificator",
        abstract: "A lightweight macOS CLI notification tool that wakes up your terminal.",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Notification title.")
    var title: String = "Terminal Notificator"
    
    @Option(name: .shortAndLong, help: "Notification message body.")
    var message: String
    
    @Flag(name: .shortAndLong, help: "Enable verbose mode for debugging.")
    var verbose: Bool = false
    
    mutating func run() throws {
        let isVerbose = self.verbose
        
        if isVerbose {
            print("[INFO] Searching for parent terminal context...")
        }
        
        let context = ProcessContext.current()
        let targetBundleId = context.bundleId ?? "com.apple.Terminal"
        
        if isVerbose {
            print("[INFO] Identified Terminal:")
            print("       Name: \(context.appName ?? "Unknown")")
            print("       Bundle ID: \(targetBundleId)")
            print("       PID: \(context.appPid.map { String($0) } ?? "Unknown")")
        }
        
        // Start a 10-second timeout failsafe (in case the user ignores the notification forever)
        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
            if isVerbose {
                print("[INFO] 10 seconds timeout reached. Exiting to prevent hanging.")
            }
            Darwin.exit(0)
        }
        
        let notifier = Notifier()
        if isVerbose {
            print("[INFO] Sending notification as \(targetBundleId)...")
        }
        
        let clicked = notifier.sendAndWait(title: title, message: message, bundleId: targetBundleId)
        
        if clicked {
            if isVerbose {
                print("[INFO] Notification clicked! Activating terminal...")
            }
            _ = context.activate()
        } else {
            if isVerbose {
                print("[INFO] Notification dismissed or expired.")
            }
        }
    }
}
