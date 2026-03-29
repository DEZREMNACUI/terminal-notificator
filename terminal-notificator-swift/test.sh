#!/bin/bash

# 获取脚本所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 确保代码已经编译（Release模式）
echo "📦 正在编译最新代码..."
swift build -c release

# 获取编译好的二进制文件路径
BINARY_PATH="./.build/release/TerminalNotificator"

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ 编译失败，找不到可执行文件: $BINARY_PATH"
    exit 1
fi

echo "✅ 编译成功！"
echo "⏳ 等待 2 秒钟... (请在此期间切换到其他窗口，比如浏览器或桌面)"

# 等待 2 秒
sleep 2

echo "🚀 发送通知！"
# 执行通知程序，并开启 verbose 模式以便查看详细日志
"$BINARY_PATH" -t "任务完成" -m "你的长耗时脚本已经运行完毕，点击返回终端。" -v

echo "✨ 脚本结束。"
