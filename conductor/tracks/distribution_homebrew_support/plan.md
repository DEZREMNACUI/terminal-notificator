# 实施计划: 分发 - Homebrew 支持

## 阶段 1: 创建 Formula 与发布指南

- [x] Task: 创建 Homebrew Formula 模板 071b288
    - 在项目根目录创建 `terminal-notificator.rb`。
    - 填入基于 Cargo 的标准安装逻辑。
    - 使用占位符 (e.g., `<URL>`, `<SHA256>`) 暂时替代具体版本信息。
- [x] Task: 编写 RELEASE.md 指南 8526bb5
    - 创建 `RELEASE.md`。
    - 记录从 `cargo build` 到 GitHub Release 再到更新 Formula 的完整步骤。
- [ ] Task: Conductor - 用户手册验证 '阶段 1: 创建 Formula 与发布指南' (协议在 workflow.md)

## 阶段 2: 文档更新与验证

- [ ] Task: 更新 README.md
    - 添加 "通过 Homebrew 安装" 章节。
    - 说明如何使用 Tap 或直接安装 Formula。
- [ ] Task: 验证 Formula (本地)
    - 编写一个简单的验证脚本或手动步骤，尝试使用 `brew install --build-from-source` 安装本地 Formula。
    - **注意**: 由于这是一个尚未发布的版本，我们可能需要模拟 source url 或仅验证语法。
- [ ] Task: Conductor - 用户手册验证 '阶段 2: 文档更新与验证' (协议在 workflow.md)
