# 项目工作流 (Project Workflow)

## 指导原则 (Guiding Principles)

1. **计划是唯一的事实来源:** 所有工作必须在 `plan.md` 中进行跟踪。
2. **技术栈是经过深思熟虑的:** 对技术栈的更改必须在实施 *之前* 记录在 `tech-stack.md` 中。
3. **测试驱动开发 (TDD):** 在实现功能之前编写单元测试。
4. **高代码覆盖率:** 目标是所有模块的代码覆盖率 >80%。
5. **用户体验至上:** 每一个决定都应优先考虑用户体验。
6. **非交互式与 CI 感知:** 优先使用非交互式命令。对监视模式工具（测试、linter）使用 `CI=true` 以确保单次执行。

## 任务工作流 (Task Workflow)

所有任务遵循严格的生命周期：

### 标准任务工作流 (Standard Task Workflow)

1. **选择任务:** 从 `plan.md` 中按顺序选择下一个可用任务。

2. **标记进行中:** 在开始工作之前，编辑 `plan.md` 并将任务从 `[ ]` 更改为 `[~]`。

3. **编写失败的测试 (红灯阶段):**
   - 为功能或错误修复创建一个新的测试文件。
   - 编写一个或多个单元测试，清楚地定义任务的预期行为和验收标准。
   - **关键:** 运行测试并确认它们如预期那样失败。这是 TDD 的“红灯”阶段。在有失败的测试之前，不要继续。

4. **实现以通过测试 (绿灯阶段):**
   - 编写使失败测试通过所需的最少应用程序代码。
   - 再次运行测试套件并确认所有测试现在都通过。这是“绿灯”阶段。

5. **重构 (可选但推荐):**
   - 在测试通过的安全保障下，重构实现代码和测试代码以提高清晰度、消除重复并增强性能，而不改变外部行为。
   - 重构后重新运行测试以确保它们仍然通过。

6. **验证覆盖率:** 使用项目选择的工具运行覆盖率报告。例如，在 Python 项目中，这可能看起来像：
   ```bash
   pytest --cov=app --cov-report=html
   ```
   目标：新代码 >80% 的覆盖率。具体工具和命令将根据语言和框架而异。

7. **记录偏差:** 如果实现与技术栈不同：
   - **停止** 实现
   - 使用新设计更新 `tech-stack.md`
   - 添加解释更改的日期注释
   - 恢复实现

8. **提交代码更改:**
   - 暂存与任务相关的所有代码更改。
   - 提出一个清晰、简洁的提交消息，例如 `feat(ui): Create basic HTML structure for calculator`。
   - 执行提交。

9. **附加任务摘要与 Git Notes:**
   - **步骤 9.1: 获取提交哈希:** 获取 *刚刚完成的提交* 的哈希 (`git log -1 --format="%H"`)。
   - **步骤 9.2: 起草笔记内容:** 为完成的任务创建一个详细的摘要。这应包括任务名称、更改摘要、所有创建/修改文件的列表以及更改的核心“原因”。
   - **步骤 9.3: 附加笔记:** 使用 `git notes` 命令将摘要附加到提交。
     ```bash
     # 上一步的笔记内容通过 -m 标志传递。
     git notes add -m "<note content>" <commit_hash>
     ```

10. **获取并记录任务提交 SHA:**
    - **步骤 10.1: 更新计划:** 阅读 `plan.md`，找到完成任务的行，将其状态从 `[~]` 更新为 `[x]`，并附加 *刚刚完成的提交* 的提交哈希的前 7 个字符。
    - **步骤 10.2: 写入计划:** 将更新的内容写回 `plan.md`。

11. **提交计划更新:**
    - **动作:** 暂存修改后的 `plan.md` 文件。
    - **动作:** 使用描述性消息提交此更改（例如，`conductor(plan): Mark task 'Create user model' as complete`）。

### 阶段完成验证和检查点协议 (Phase Completion Verification and Checkpointing Protocol)

**触发:** 此协议在完成一个任务并同时也结束了 `plan.md` 中的一个阶段后立即执行。

1.  **宣布协议开始:** 通知用户阶段已完成，验证和检查点协议已开始。

2.  **确保阶段变更的测试覆盖率:**
    -   **步骤 2.1: 确定阶段范围:** 要识别此阶段更改的文件，您必须首先找到起点。阅读 `plan.md` 以找到 *上一个* 阶段检查点的 Git 提交 SHA。如果不存在上一个检查点，则范围是自第一次提交以来的所有更改。
    -   **步骤 2.2: 列出更改的文件:** 执行 `git diff --name-only <previous_checkpoint_sha> HEAD` 以获取此阶段修改的所有文件的精确列表。
    -   **步骤 2.3: 验证并创建测试:** 对于列表中的每个文件：
        -   **关键:** 首先，检查其扩展名。排除非代码文件（例如 `.json`, `.md`, `.yaml`）。
        -   对于每个剩余的代码文件，验证是否存在相应的测试文件。
        -   如果缺少测试文件，您 **必须** 创建一个。在编写测试之前，**首先，分析存储库中的其他测试文件以确定正确的命名约定和测试风格。** 新测试 **必须** 验证此阶段任务（`plan.md`）中描述的功能。

3.  **执行带有主动调试的自动化测试:**
    -   在执行之前，您 **必须** 宣布您将用于运行测试的确切 shell 命令。
    -   **示例公告:** "我现在将运行自动化测试套件以验证阶段。**命令:** `CI=true npm test`"
    -   执行宣布的命令。
    -   如果测试失败，您 **必须** 通知用户并开始调试。您可以尝试提出修复方案 **最多两次**。如果在您第二次提出的修复后测试仍然失败，您 **必须停止**，报告持续的失败，并询问用户的指导。

4.  **提出详细的、可操作的手动验证计划:**
    -   **关键:** 要生成计划，首先分析 `product.md`、`product-guidelines.md` 和 `plan.md` 以确定完成阶段的用户面向目标。
    -   您 **必须** 生成一个分步计划，引导用户完成验证过程，包括任何必要的命令和特定的预期结果。
    -   您呈现给用户的计划 **必须** 遵循此格式：

        **对于前端更改:**
        ```
        自动化测试已通过。为了进行手动验证，请遵循以下步骤：

        **手动验证步骤:**
        1.  **使用以下命令启动开发服务器:** `npm run dev`
        2.  **在浏览器中打开:** `http://localhost:3000`
        3.  **确认您看到:** 新的用户个人资料页面，正确显示用户的姓名和电子邮件。
        ```

        **对于后端更改:**
        ```
        自动化测试已通过。为了进行手动验证，请遵循以下步骤：

        **手动验证步骤:**
        1.  **确保服务器正在运行。**
        2.  **在终端中执行以下命令:** `curl -X POST http://localhost:8080/api/v1/users -d '{"name": "test"}'`
        3.  **确认您收到:** 状态为 `201 Created` 的 JSON 响应。
        ```

5.  **等待明确的用户反馈:**
    -   在提出详细计划后，询问用户确认："**这是否符合您的期望？请确认是或提供关于需要更改的内容的反馈。**"
    -   **暂停** 并等待用户的响应。在没有明确的是或确认的情况下不要继续。

6.  **创建检查点提交:**
    -   暂存所有更改。如果此步骤中没有发生更改，请继续进行空提交。
    -   使用清晰简洁的消息执行提交（例如，`conductor(checkpoint): Checkpoint end of Phase X`）。

7.  **使用 Git Notes 附加可审计的验证报告:**
    -   **步骤 7.1: 起草笔记内容:** 创建详细的验证报告，包括自动化测试命令、手动验证步骤和用户的确认。
    -   **步骤 7.2: 附加笔记:** 使用 `git notes` 命令和上一步的完整提交哈希将完整报告附加到检查点提交。

8.  **获取并记录阶段检查点 SHA:**
    -   **步骤 8.1: 获取提交哈希:** 获取 *刚刚创建的检查点提交* 的哈希 (`git log -1 --format="%H"`)。
    -   **步骤 8.2: 更新计划:** 阅读 `plan.md`，找到完成阶段的标题，并以 `[checkpoint: <sha>]` 格式附加提交哈希的前 7 个字符。
    -   **步骤 8.3: 写入计划:** 将更新的内容写回 `plan.md`。

9. **提交计划更新:**
    - **动作:** 暂存修改后的 `plan.md` 文件。
    - **动作:** 使用遵循 `conductor(plan): Mark phase '<PHASE NAME>' as complete` 格式的描述性消息提交此更改。

10.  **宣布完成:** 通知用户阶段已完成，检查点已创建，详细的验证报告已作为 git note 附加。

### 质量门槛 (Quality Gates)

在标记任何任务完成之前，请验证：

- [ ] 所有测试通过
- [ ] 代码覆盖率符合要求 (>80%)
- [ ] 代码遵循项目的代码风格指南（定义在 `code_styleguides/` 中）
- [ ] 所有公共函数/方法都有文档记录（例如，docstrings, JSDoc, GoDoc）
- [ ] 强制执行类型安全（例如，类型提示, TypeScript types, Go types）
- [ ] 没有 linting 或静态分析错误（使用项目配置的工具）
- [ ] 在移动设备上正常工作（如果适用）
- [ ] 如果需要，更新文档
- [ ] 没有引入安全漏洞

## 开发命令 (Development Commands)

**AI AGENT INSTRUCTION: This section should be adapted to the project's specific language, framework, and build tools.**

### 设置 (Setup)
```bash
# Example: Commands to set up the development environment (e.g., install dependencies, configure database)
# e.g., for a Node.js project: npm install
# e.g., for a Go project: go mod tidy
```

### 日常开发 (Daily Development)
```bash
# Example: Commands for common daily tasks (e.g., start dev server, run tests, lint, format)
# e.g., for a Node.js project: npm run dev, npm test, npm run lint
# e.g., for a Go project: go run main.go, go test ./..., go fmt ./...
```

### 提交前 (Before Committing)
```bash
# Example: Commands to run all pre-commit checks (e.g., format, lint, type check, run tests)
# e.g., for a Node.js project: npm run check
# e.g., for a Go project: make check (if a Makefile exists)
```

## 测试要求 (Testing Requirements)

### 单元测试 (Unit Testing)
- 每个模块必须有相应的测试。
- 使用适当的测试设置/拆卸机制（例如，fixtures, beforeEach/afterEach）。
- 模拟外部依赖。
- 测试成功和失败的情况。

### 集成测试 (Integration Testing)
- 测试完整的用户流程
- 验证数据库事务
- 测试身份验证和授权
- 检查表单提交

### 移动测试 (Mobile Testing)
- 尽可能在实际 iPhone 上测试
- 使用 Safari 开发者工具
- 测试触摸交互
- 验证响应式布局
- 检查 3G/4G 上的性能

## 代码审查流程 (Code Review Process)

### 自我审查清单 (Self-Review Checklist)
在请求审查之前：

1. **功能性**
   - 功能按规定工作
   - 处理边缘情况
   - 错误消息用户友好

2. **代码质量**
   - 遵循风格指南
   - 应用 DRY 原则
   - 清晰的变量/函数名称
   - 适当的注释

3. **测试**
   - 单元测试全面
   - 集成测试通过
   - 覆盖率充足 (>80%)

4. **安全性**
   - 没有硬编码的密钥
   - 存在输入验证
   - 防止 SQL 注入
   - 实施 XSS 保护

5. **性能**
   - 数据库查询优化
   - 图像优化
   - 在需要的地方实施缓存

6. **移动体验**
   - 触摸目标充足 (44x44px)
   - 文本无需缩放即可阅读
   - 移动设备性能可接受
   - 交互感觉原生

## 提交指南 (Commit Guidelines)

### 消息格式 (Message Format)
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### 类型 (Types)
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 仅文档
- `style`: 格式化，缺少分号等
- `refactor`: 既不修复错误也不添加功能的代码更改
- `test`: 添加缺失的测试
- `chore`: 维护任务

### 示例 (Examples)
```bash
git commit -m "feat(auth): Add remember me functionality"
git commit -m "fix(posts): Correct excerpt generation for short posts"
git commit -m "test(comments): Add tests for emoji reaction limits"
git commit -m "style(mobile): Improve button touch targets"
```

## 完成的定义 (Definition of Done)

当满足以下条件时，任务完成：

1. 所有代码按规范实现
2. 单元测试编写并通过
3. 代码覆盖率符合项目要求
4. 文档完成（如果适用）
5. 代码通过所有配置的 linting 和静态分析检查
6. 在移动设备上完美工作（如果适用）
7. 实现说明添加到 `plan.md`
8. 更改以正确的消息提交
9. 带有任务摘要的 Git note 附加到提交

## 紧急程序 (Emergency Procedures)

### 生产环境中的严重 Bug
1. 从 main 创建 hotfix 分支
2. 为 bug 编写失败测试
3. 实现最小修复
4. 彻底测试，包括移动设备
5. 立即部署
6. 在 plan.md 中记录

### 数据丢失
1. 停止所有写入操作
2. 从最新备份恢复
3. 验证数据完整性
4. 记录事件
5. 更新备份程序

### 安全漏洞
1. 立即轮换所有密钥
2. 审查访问日志
3. 修补漏洞
4. 通知受影响的用户（如果有）
5. 记录并更新安全程序

## 部署工作流 (Deployment Workflow)

### 部署前清单
- [ ] 所有测试通过
- [ ] 覆盖率 >80%
- [ ] 没有 linting 错误
- [ ] 移动测试完成
- [ ] 环境变量已配置
- [ ] 数据库迁移准备就绪
- [ ] 备份已创建

### 部署步骤
1. 将功能分支合并到 main
2. 用版本标记发布
3. 推送到部署服务
4. 运行数据库迁移
5. 验证部署
6. 测试关键路径
7. 监控错误

### 部署后
1. 监控分析
2. 检查错误日志
3. 收集用户反馈
4. 计划下一次迭代

## 持续改进 (Continuous Improvement)

- 每周审查工作流
- 根据痛点更新
- 记录经验教训
- 优化用户幸福感
- 保持简单和可维护