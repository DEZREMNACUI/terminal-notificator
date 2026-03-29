#!/bin/bash

# 获取脚本所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "⏳ 等待 2 秒钟... (请在此期间切换到其他窗口，比如浏览器或桌面)"

sleep 2

echo "🚀 发送通知！"
# 执行通知程序，自动检测终端应用
./terminal-notificator  -v

echo "✨ 脚本结束。"
