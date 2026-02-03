class TerminalNotificator < Formula
  desc "Lightweight, context-aware macOS terminal notifier in Rust"
  homepage "https://github.com/dezremnacui/terminal-notificator"
  url "https://github.com/dezremnacui/terminal-notificator/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "dbc6bfbacdb2316d9e485ee06369ead427bea91e8bb8a65f1e95ec3bdcf63e9d"
  license "MIT"

  depends_on "rust" => :build

  def install
    # 打印当前目录内容，帮助排查路径问题
    system "ls", "-R"
    
    # 使用标准 cargo install，但移除 --locked 限制（如果存在干扰）
    # 同时确保使用 Homebrew 的 Rust 环境
    system "cargo", "install", *std_cargo_args
  end

  test do
    system "#{bin}/terminal-notificator", "--help"
  end
end
