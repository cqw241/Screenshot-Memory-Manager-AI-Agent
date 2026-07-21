# Windows encoding rules

- The default shell is PowerShell 7.
- Treat all repository text files as UTF-8 unless the existing file uses another encoding.
- When reading or writing text with Python, always specify encoding="utf-8".
- When using PowerShell file commands, specify -Encoding utf8 when practical.
- Do not invoke Windows PowerShell 5.1 (`powershell.exe`) for repository file operations.
- Before modifying files containing Chinese or other non-ASCII text, inspect the resulting git diff.
- Avoid piping Chinese text through native programs unless their stdin encoding is known.
- Do not change file encoding or line endings unless explicitly required.