# Sample Python Code for Testing

This directory contains sample Python files with intentional code quality issues for testing the code reviewer.

These files will be copied to `/app/code_to_review/` during Docker build and analyzed by your `code_reviewer.py` script.

**Files:**
- `bad_security.py` - Security vulnerabilities (SQL injection, hardcoded secrets, eval)
- `complex_function.py` - Complexity issues (long functions, deep nesting, high cyclomatic complexity)
- `style_issues.py` - Style violations (naming conventions, unused variables)

Your code reviewer should detect issues in all these files and generate a comprehensive report.
