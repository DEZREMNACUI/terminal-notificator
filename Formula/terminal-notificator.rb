class TerminalNotificator < Formula
  desc "Lightweight, context-aware macOS terminal notifier in Rust"
  homepage "https://github.com/dezremnacui/terminal-notificator"
  url "https://github.com/dezremnacui/terminal-notificator/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "8f0c5fee7c2accb718bcf16462238f2cd2bfa177d004cb5c0e9a4a9be086adf4"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    system "#{bin}/terminal-notificator", "--help"
  end
end