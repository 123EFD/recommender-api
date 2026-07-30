---
name: Auto Commit Message Generator
description: Forces the agent to automatically generate and provide a Git commit message whenever files are changed, without needing to be asked.
---

# Auto Commit Message Generator

## Trigger Condition
Activate this skill automatically whenever you complete a task that involves creating, modifying, or deleting code files in the user's workspace.

## Agent Instructions
When this skill is triggered, you MUST append a formatted Git commit message at the very end of your final response to the user. Do not wait for the user to ask you to write a commit message; you must provide it proactively.

### Commit Message Formatting Rules
1. **Follow Conventional Commits**: Start the message with the appropriate prefix based on the type of change:
   - `feat:` for new features or significant UI additions.
   - `fix:` for bug fixes, crash resolutions, or logic corrections.
   - `refactor:` for code restructuring without changing external behavior.
   - `style:` for formatting, theme updates, or UI polish.
   - `docs:` for changes to documentation or README files.
   - `chore:` for updating dependencies or build tasks.
2. **Subject Line**: Keep the first line under 50 characters, use the imperative mood (e.g., "Add feature" not "Added feature"), and do not end with a period.
3. **Body (Optional but Recommended)**: If the change is complex, leave a blank line after the subject and provide a bulleted list detailing *what* was changed and *why*.

### Output Format
Format the output in a clean markdown code block so the user can easily copy and paste it into their terminal or version control UI. 

**Example:**
Here is a commit message for your changes:
```text
fix: resolve overlapping nodes in flowchart layouts

- Implemented `calculateSubtreeWidth` in LayoutEngine to dynamically allocate horizontal space based on exact text width.
- Added `visited` sets to Hierarchical layout to prevent Stack Overflow crashes on cyclic graphs.
- Replaced fixed 220px horizontal spacing with exact boundary calculations.
```
