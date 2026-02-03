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

## 4. 更新 Homebrew Formula

1.  打开项目根目录下的 `terminal-notificator.rb`。
2.  更新 `url` 字段中的版本号。
3.  更新 `sha256` 字段为上一步计算出的值。
4.  提交更改: `git commit -am "chore(dist): Update Homebrew formula for vx.y.z"`
5.  推送更改: `git push`

现在，用户可以通过以下方式安装新版本:

```bash
brew install --build-from-source https://raw.githubusercontent.com/youruser/terminal-notificator/master/terminal-notificator.rb
```

或者，如果您设置了 tap，用户只需运行 `brew upgrade terminal-notificator`。
