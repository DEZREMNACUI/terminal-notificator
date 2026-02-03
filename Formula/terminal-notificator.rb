class TerminalNotificator < Formula
  desc "Lightweight, context-aware macOS terminal notifier in Rust"
  homepage "https://github.com/youruser/terminal-notificator"
  url "https://github.com/youruser/terminal-notificator/archive/refs/tags/v<VERSION>.tar.gz"
  sha256 "<SHA256>"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    system "#{bin}/terminal-notificator", "--help"
  end
end
