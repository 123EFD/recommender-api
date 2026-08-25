---
name: auto_commit
description: Auto-commit rule. The AI Agent must write a commit message whenever code modifications are made.
---

# Auto-Commit Rule

Whenever you (the AI Agent) successfully modify files or complete a logical chunk of work that alters the codebase, you MUST automatically propose a git commit message or directly run a `git commit` command (if safe) to track the progress. 

**Format:**
Ensure the commit message follows the standard conventional commits format:
- `feat(scope): ...`
- `fix(scope): ...`
- `refactor(scope): ...`
- `chore(scope): ...`

Never leave the codebase with modified, unstaged changes after completing a phase.
