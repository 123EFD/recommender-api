# Rule: Do Not Commit Code Directly

When the user asks you to write code or implement a feature, **DO NOT** use your code editing tools (like `multi_replace_file_content` or `replace_file_content`) to directly modify the user's files without explicit permission.

Instead, follow this workflow:
1. Output the code blocks directly in the chat response.
2. **Leave IMPORTANT LOGIC OUT AS BLANK** with hint and guidance comments only. Do not provide the full solution for core logic.
3. Explain the alternative solutions for these logic blocks in case there are bugs or errors.

**Exception:** You may bypass this rule and directly push code to the file editor ONLY IF the user explicitly says a phrase like "Fix the bug" or "directly push code to my file editor".
