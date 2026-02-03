# 发布指南 (Release Guide)

本指南说明了如何发布 `terminal-notificator` 的新版本并更新 Homebrew Formula。

## 1. 准备发布

1.  **更新版本号**:
    - 修改 `Cargo.toml` 中的 `version` 字段。
    - 运行 `cargo check` 确保一切正常。
    - 提交更改: `git commit -am "chore: Bump version to x.y.z"`

2.  **打标签**:
    - 创建 git 标签: `git tag -a vx.y.z -m "Release vx.y.z"`
    - 推送提交和标签: `git push origin master --tags`

## 2. 创建 GitHub Release

1.  前往 GitHub 仓库的 "Releases" 页面。
2.  点击 "Draft a new release"。
3.  选择刚刚推送的标签 `vx.y.z`。
4.  填写标题和发布说明。
5.  **重要**: GitHub 会自动将源代码打包为 `tar.gz`。这就是我们需要的文件。
6.  点击 "Publish release"。

## 3. 获取 SHA256

发布后，我们需要获取源码压缩包的 SHA256 校验和。

```bash
# 下载源码包 (将 x.y.z 替换为实际版本)
curl -L -o terminal-notificator.tar.gz https://github.com/youruser/terminal-notificator/archive/refs/tags/vx.y.z.tar.gz

# 计算 SHA256
shasum -a 256 terminal-notificator.tar.gz
```

复制输出的哈希值。

## 4. 更新 Homebrew Formula (Tap)

为了支持 `brew install terminal-notificator`，建议创建一个名为 `homebrew-tap` 的专门仓库，或者直接在本项目中维护（如果本项目本身作为 Tap）。

1.  **更新 Formula**:
    - 打开 `Formula/terminal-notificator.rb`。
    - 更新 `url` 和 `sha256`。
2.  **提交并推送**:
    - `git commit -am "chore(dist): Update formula for vx.y.z"`
    - `git push`

## 5. 用户安装方式

用户只需执行以下两步：

```bash
brew tap youruser/tap //brew tap DEZREMNACUI/repo https://github.com/DEZREMNACUI/terminal-notificator 
brew install terminal-notificator
```

一旦安装过一次，后续升级只需：

```bash
brew upgrade terminal-notificator
```
