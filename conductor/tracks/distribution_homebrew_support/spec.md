# 规格说明书: 分发 - Homebrew 支持

## 1. 概述
本 Track 旨在为 `terminal-notificator` 提供 Homebrew 安装支持，使其能够通过 `brew install terminal-notificator` (在 tap 中) 或类似命令轻松安装。这将涉及创建 Formula 文件、定义发布流程以及更新项目文档。

## 2. 交付物

### 2.1 Homebrew Formula
- **文件**: `terminal-notificator.rb` (位于项目根目录或 `Formula/` 目录)。
- **内容**:
    - 描述 (`desc`)
    - 主页 (`homepage`)
    - 下载 URL (`url`) - 指向 GitHub Release 的 tar.gz
    - SHA256 校验和 (`sha256`)
    - 依赖 (`depends_on "rust" => :build`)
    - 安装脚本 (`install`)

### 2.2 发布文档
- **文件**: `RELEASE.md`
- **内容**:
    - 详细的分步指南，说明如何发布新版本。
    - 如何构建 release 二进制文件。
    - 如何计算 SHA256。
    - 如何更新 Formula 文件。

### 2.3 用户文档更新
- **文件**: `README.md`
- **更新**: 添加通过 Homebrew 安装的说明部分。

## 3. 技术约束
- Formula 必须符合 Homebrew Ruby 语法规范。
- 必须验证 Formula 在本地能够成功构建和安装。

## 4. 验收标准
- [ ] 存在有效的 `terminal-notificator.rb` 文件。
- [ ] `RELEASE.md` 清晰记录了发布流程。
- [ ] `README.md` 包含 Homebrew 安装说明。
- [ ] (可选/手动) 在本地运行 `brew install --build-from-source ./terminal-notificator.rb` 成功。
