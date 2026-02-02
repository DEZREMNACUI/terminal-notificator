use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// The notification title
    #[arg(short, long, default_value = "Terminal Notificator")]
    pub title: String,

    /// The notification message body
    #[arg(short, long)]
    pub message: String,

    /// Verbose mode
    #[arg(short, long)]
    pub verbose: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verify_cli() {
        use clap::CommandFactory;
        Cli::command().debug_assert();
    }

    #[test]
    fn test_parse_args() {
        let args = vec!["terminal-notificator", "-t", "Test Title", "-m", "Test Message"];
        let cli = Cli::parse_from(args);
        assert_eq!(cli.title, "Test Title");
        assert_eq!(cli.message, "Test Message");
    }

    #[test]
    fn test_defaults() {
        let args = vec!["terminal-notificator", "-m", "Message Only"];
        let cli = Cli::parse_from(args);
        assert_eq!(cli.title, "Terminal Notificator");
        assert_eq!(cli.message, "Message Only");
    }
}
