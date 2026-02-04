mod cli;
mod context;
mod notifier;

use clap::Parser;
use cli::Cli;
use context::ProcessContext;
use notifier::Notifier;
use std::thread;
use std::time::Duration;

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

    // Spawn a monitor thread to check for focus changes
    // This allows us to exit if the user manually switches back to the app,
    // even while the main thread is blocked waiting for the notification click.
    let ctx_clone = ctx.clone();
    let verbose = args.verbose;

    thread::spawn(move || {
        loop {
            if ctx_clone.is_current_app_focused() {
                if verbose {
                    println!("Monitor: Target app is focused. Exiting.");
                }
                std::process::exit(0);
            }
            thread::sleep(Duration::from_millis(500));
        }
    });

    let notifier = Notifier::new();
    println!("Sending notification: {} - {}", args.title, args.message);
    println!("Waiting for click or focus switch to activate parent application...");

    // Notification must be handled on the main thread for callbacks to work correctly on macOS
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
