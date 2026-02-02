mod cli;
mod context;
mod notifier;

use clap::Parser;
use cli::Cli;

fn main() {
    let args = Cli::parse();
    println!("Title: {}", args.title);
    println!("Message: {}", args.message);
}
