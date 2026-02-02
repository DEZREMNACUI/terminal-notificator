# 通用代码风格指南 (General Code Style Guide)

本指南概述了适用于所有语言的通用最佳实践，重点关注可读性、可维护性和一致性。

## 1. 原则 (Principles)

*   **清晰优于简洁 (Clarity over brevity):** 代码被阅读的次数多于被编写的次数。为了可读性而优化，而不是为了减少击键次数。
*   **一致性是关键 (Consistency is key):** 即使规则不是您喜欢的，也要遵循项目的现有风格。
*   **DRY (Don't Repeat Yourself - 不要重复自己):** 将重复的逻辑提取到函数或模块中。
*   **KISS (Keep It Simple, Stupid - 保持简单):** 避免过度工程。编写尽可能简单的代码来解决问题。
*   **YAGNI (You Aren't Gonna Need It - 您不需要它):** 除非现在需要，否则不要实现功能。

## 2. 命名约定 (Naming Conventions)

*   **使用有意义的名称:** 变量名应该描述它们包含的内容。函数名应该描述它们做什么。
    *   **Bad:** `d`, `x`, `doIt()`
    *   **Good:** `daysSinceCreation`, `userIndex`, `calculateTotalTax()`
*   **避免使用魔术数字/字符串:** 使用命名常量。
    *   **Bad:** `if (status == 1) ...`
    *   **Good:** `const STATUS_ACTIVE = 1; if (status == STATUS_ACTIVE) ...`
*   **遵循特定语言的惯例:**
    *   **Python:** `snake_case` 用于变量/函数，`CamelCase` 用于类。
    *   **JavaScript:** `camelCase` 用于变量/函数，`PascalCase` 用于类。
    *   **Go:** `CamelCase` (exported) 或 `camelCase` (unexported)。
    *   **Rust:** `snake_case` 用于变量/函数/模块，`CamelCase` 用于类型/Trait。

## 3. 格式化 (Formatting)

*   **缩进:** 坚持一种缩进样式（通常是 2 个或 4 个空格）。**不要混合使用制表符和空格。**
*   **行长度:** 将行限制在合理的长度（例如，80、100 或 120 个字符），以避免横向滚动。
*   **空白:** 明智地使用空白来分隔逻辑相关的代码块。
*   **大括号:** 遵循语言的标准大括号位置（例如，K&R 风格用于 JS/Go/Rust，Allman 风格用于 C#）。

## 4. 注释与文档 (Comments & Documentation)

*   **注释 "Why" 而不是 "What":** 代码应该尽可能自我解释。使用注释来解释复杂的逻辑或非显而易见的决定背后的 *原因*。
*   **保持注释更新:** 错误的注释比没有注释更糟糕。
*   **TODOs:** 使用 `TODO` 或 `FIXME` 来标记需要稍后处理的区域，最好带有票证/问题编号。

## 5. 函数与方法 (Functions & Methods)

*   **单一职责:** 一个函数应该做一件事，并且做好。
*   **简短:** 这里的目标是函数可以放在一个屏幕上。如果函数太长，请将其分解。
*   **参数数量:** 将参数数量保持在最低限度（理想情况下少于 4 个）。如果需要更多，请考虑传递对象或结构体。

## 6. 错误处理 (Error Handling)

*   **不要忽略错误:** 始终处理潜在的错误。不要吞下异常或忽略返回值。
*   **提供上下文:** 记录或返回错误时，提供足够的上下文来调试问题。
*   **故障快速:** 在函数开始时验证输入并在出现问题时立即失败。

## 7. 版本控制 (Version Control)

*   **原子提交:** 使提交变得小且专注于单一更改。
*   **有意义的提交消息:** 遵循常规提交格式 (Conventional Commits) (`feat: ...`, `fix: ...`)。解释 *为什么* 进行了更改。
*   **审查前进行 Lint:** 在提交之前运行 linter 和 formatter。