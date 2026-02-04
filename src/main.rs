mod cli;
mod context;
mod notifier;

use clap::Parser;
use cli::Cli;
use context::ProcessContext;
use notifier::Notifier;

fn main() {
    let args = Cli::parse();

    if args.verbose {
        println!("Initializing context...");
    }

    let ctx = ProcessContext::current();

    if args.verbose {
        println!("Detected App: {:?}", ctx.app_name);
        println!("Bundle ID: {:?}", ctx.bundle_id);
    }

    // Start monitoring for focus changes using system events (NSWorkspace)
    // This will cause the process to exit if the target app is activated manually.
    ctx.start_focus_monitoring();

    let notifier = Notifier::new();
    println!("Sending notification: {} - {}", args.title, args.message);
    println!("Waiting for click or focus switch to activate parent application...");

    // Notification must be handled on the main thread for callbacks to work correctly on macOS.
    // This blocking call also drives the main run loop, which processes the 
    // NSWorkspace notifications we registered for in start_focus_monitoring().
    if notifier.send_and_wait(&args.title, &args.message) {
        println!("Notification clicked! Activating...");
        if ctx.activate() {
            println!("Successfully activated parent application.");
        } else {
            println!("Failed to activate parent application.");
        }
    } else {
        println!("Notification ignored or closed.");
    }
}
