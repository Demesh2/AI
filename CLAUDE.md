# Code Review Plugin — claude-plugins-official/code-review

This repository has the **code-review** plugin installed. Follow these guidelines when working with code.

## Code Review Process

Before committing any changes, run the automated code review:

```bash
bash scripts/code-review.sh
```

## Review Checklist

When writing or modifying code, ensure:

### Security
- No hardcoded secrets, API keys, passwords, or tokens
- Input validation at system boundaries
- No SQL injection, XSS, or command injection vulnerabilities

### Quality
- Functions are focused and under 80-100 lines
- No leftover debug statements (console.log, print, breakpoint, binding.pry)
- No trailing whitespace
- TODO/FIXME comments are tracked and addressed before merge

### Best Practices
- Code is readable and self-documenting
- Changes are minimal and focused on the task
- No unnecessary abstractions or over-engineering
- Tests cover new functionality and edge cases

## Hooks

The `.claude/settings.json` configures hooks that remind you to run the code review script after editing files. The `scripts/code-review.sh` script performs automated checks for common issues.
