mod cli;
mod context;
mod notifier;

use clap::Parser;
use cli::Cli;
use context::ProcessContext;

fn main() {
    let args = Cli::parse();
    
    if args.verbose {
        println!("Initializing context...");
    }

    let ctx = ProcessContext::current();

    if args.verbose {
        println!("Current PID: {}", ctx.pid);
        println!("Parent PID: {:?}", ctx.parent_pid);
        println!("Detected App: {:?}", ctx.app_name);
        println!("Bundle ID: {:?}", ctx.bundle_id);
    }

    println!("Title: {}", args.title);
    println!("Message: {}", args.message);
}