#!/bin/bash

# 获取脚本所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 构建 .app 包
echo "📦 正在构建 .app 包..."
./build.sh

# 获取 .app 内的二进制文件路径
APP_PATH="./apps/default/TerminalNotificator.app/Contents/MacOS/TerminalNotificator"

if [ ! -f "$APP_PATH" ]; then
    echo "❌ 构建失败，找不到可执行文件: $APP_PATH"
    exit 1
fi

echo "✅ 构建成功！"
echo "⏳ 等待 2 秒钟... (请在此期间切换到其他窗口，比如浏览器或桌面)"

# 等待 2 秒
sleep 2

echo "🚀 发送通知！"
# 执行通知程序，并开启 verbose 模式以便查看详细日志
"$APP_PATH" -t "任务完成" -m "你的长耗时脚本已经运行完毕，点击返回终端。" -v

echo "✨ 脚本结束。"
