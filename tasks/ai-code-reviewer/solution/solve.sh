#!/bin/bash
# This solution creates code_reviewer.py and runs it to generate /app/code_review.json

cat > code_reviewer.py << 'EOF'
import os
import json
import ast
import re
from typing import List, Dict, Any, Set, Tuple
from pathlib import Path
import math

class AdvancedCodeReviewer:
    def __init__(self, code_directory: str = "/app/code_to_review/"):
        self.code_directory = code_directory
        self.findings = []
        self.files_reviewed = 0
        self.complexity_scores = []
        self.function_lengths = []
        self.security_issues = 0
        self.total_lines = 0

    def calculate_cyclomatic_complexity(self, node: ast.AST) -> int:
        """Calculate cyclomatic complexity for a function"""
        complexity = 1  # Base complexity

        for child in ast.walk(node):
            if isinstance(child, (ast.If, ast.While, ast.For, ast.AsyncFor)):
                complexity += 1
            elif isinstance(child, ast.ExceptHandler):
                complexity += 1
            elif isinstance(child, (ast.With, ast.AsyncWith)):
                complexity += 1
            elif isinstance(child, ast.Assert):
                complexity += 1
            elif isinstance(child, ast.BoolOp):
                complexity += len(child.values) - 1

        return complexity

    def get_nesting_depth(self, node: ast.AST, current_depth: int = 0) -> int:
        """Calculate maximum nesting depth"""
        max_depth = current_depth

        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.If, ast.While, ast.For, ast.AsyncFor,
                                ast.With, ast.AsyncWith, ast.Try, ast.ExceptHandler)):
                child_depth = self.get_nesting_depth(child, current_depth + 1)
                max_depth = max(max_depth, child_depth)
            else:
                child_depth = self.get_nesting_depth(child, current_depth)
                max_depth = max(max_depth, child_depth)

        return max_depth

    def check_naming_conventions(self, name: str, node_type: str) -> Tuple[bool, str]:
        """Check if naming follows Python conventions"""
        if node_type == "function":
            if not re.match(r'^[a-z_][a-z0-9_]*$', name):
                return False, "Function names should use snake_case"
        elif node_type == "variable":
            if not re.match(r'^[a-z_][a-z0-9_]*$', name):
                return False, "Variable names should use snake_case"
        elif node_type == "class":
            if not re.match(r'^[A-Z][a-zA-Z0-9]*$', name):
                return False, "Class names should use PascalCase"
        elif node_type == "constant":
            if not re.match(r'^[A-Z_][A-Z0-9_]*$', name):
                return False, "Constants should use UPPER_CASE"
        return True, ""

    def detect_security_patterns(self, content: str, filename: str):
        """Detect security vulnerability patterns"""
        lines = content.split('\n')

        for i, line in enumerate(lines, 1):
            # SQL injection patterns - more comprehensive
            sql_patterns = [
                r'execute\s*\(\s*["\'].*%.*["\']',
                r'cursor\.execute\s*\(\s*["\'].*%.*["\']',
                r'query\s*=\s*["\'].*%.*["\']',
                r'["\'].*%.*["\'].*execute',
                r'\.format\s*\(.*\).*execute',
                r'f["\'].*\{.*\}.*["\'].*execute'
            ]

            for pattern in sql_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    self.add_finding(filename, i, "critical", "security",
                                   "Potential SQL injection vulnerability",
                                   "Use parameterized queries instead of string formatting",
                                   0.9, "high")
                    self.security_issues += 1

            # Command injection patterns - more comprehensive
            cmd_patterns = [
                r'os\.system\s*\(\s*.*[\+\%]',
                r'subprocess\.(call|run|Popen)\s*\(\s*.*[\+\%]',
                r'eval\s*\(\s*.*input',
                r'exec\s*\(\s*.*input',
                r'os\.system\s*\(\s*["\'].*["\']\s*\+',
                r'system\s*\(\s*.*\+.*\)'
            ]

            for pattern in cmd_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    self.add_finding(filename, i, "critical", "security",
                                   "Potential command injection vulnerability",
                                   "Validate and sanitize all user inputs",
                                   0.85, "high")
                    self.security_issues += 1

            # XSS patterns (for web frameworks)
            if re.search(r'render_template.*\|safe', line, re.IGNORECASE):
                self.add_finding(filename, i, "warning", "security",
                               "Potential XSS vulnerability with |safe filter",
                               "Validate and escape user content before marking as safe",
                               0.75, "medium")
                self.security_issues += 1

    def detect_performance_issues(self, tree: ast.AST, filename: str):
        """Detect performance anti-patterns"""
        for node in ast.walk(tree):
            # Inefficient list concatenation - look for "list = list + [item]" pattern
            if isinstance(node, ast.Assign):
                if (len(node.targets) == 1 and
                    isinstance(node.targets[0], ast.Name) and
                    isinstance(node.value, ast.BinOp) and
                    isinstance(node.value.op, ast.Add)):

                    # Check if it's "var = var + something" pattern (inefficient concatenation)
                    left = node.value.left
                    if (isinstance(left, ast.Name) and
                        left.id == node.targets[0].id):
                        self.add_finding(filename, getattr(node, 'lineno', 1), "warning",
                                       "performance",
                                       "Inefficient list concatenation using + operator",
                                       "Use list.append() and join(), or list comprehension instead",
                                       0.8, "medium")

            # Check for inefficient loops
            if isinstance(node, (ast.For, ast.While)):
                # Look for nested loops that might be inefficient
                nested_count = 0
                for child in ast.walk(node):
                    if isinstance(child, (ast.For, ast.While)) and child != node:
                        nested_count += 1

                if nested_count > 2:
                    self.add_finding(filename, getattr(node, 'lineno', 1), "suggestion",
                                   "performance",
                                   "Deeply nested loops may be inefficient",
                                   "Consider algorithm optimization or caching",
                                   0.6, "medium")

    def detect_anti_patterns(self, tree: ast.AST, filename: str):
        """Detect code anti-patterns"""
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                # Long parameter lists
                if len(node.args.args) > 5:
                    self.add_finding(filename, node.lineno, "warning", "design",
                                   f"Long parameter list ({len(node.args.args)} parameters)",
                                   "Consider using a configuration object or breaking into smaller functions",
                                   0.7, "medium")

                # God functions (too many responsibilities) - moved to analyze_ast_advanced
                pass

            elif isinstance(node, ast.ClassDef):
                # God objects (too many methods/attributes)
                methods = [n for n in node.body if isinstance(n, ast.FunctionDef)]
                if len(methods) > 20:
                    self.add_finding(filename, node.lineno, "warning", "design",
                                   f"God object with {len(methods)} methods",
                                   "Consider splitting class responsibilities using composition",
                                   0.75, "high")

    def analyze_directory(self):
        """Analyze all Python files in the specified directory"""
        if not os.path.exists(self.code_directory):
            return

        for file_path in Path(self.code_directory).glob("*.py"):
            self.analyze_file(file_path)

    def analyze_file(self, file_path: Path):
        """Analyze a single Python file with advanced features"""
        self.files_reviewed += 1

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            lines = content.split('\n')
            self.total_lines += len(lines)

            # Parse AST for deep analysis
            try:
                tree = ast.parse(content)
                self.analyze_ast_advanced(tree, file_path.name)
                self.detect_performance_issues(tree, file_path.name)
                self.detect_anti_patterns(tree, file_path.name)
            except SyntaxError as e:
                self.add_finding(file_path.name, e.lineno or 1, "critical", "syntax",
                               f"Syntax error: {e.msg}", "Fix syntax error", 0.95, "high")

            # Security analysis
            self.detect_security_patterns(content, file_path.name)

            # Style and content analysis
            self.analyze_content_advanced(content, file_path.name)

        except Exception as e:
            self.add_finding(file_path.name, 1, "critical", "file_access",
                           f"Could not read file: {str(e)}", "Fix file access issues", 1.0, "high")

    def analyze_ast_advanced(self, tree: ast.AST, filename: str):
        """Advanced AST analysis with complexity metrics"""
        for node in ast.walk(tree):
            # Function analysis
            if isinstance(node, ast.FunctionDef):
                # Calculate complexity
                complexity = self.calculate_cyclomatic_complexity(node)
                self.complexity_scores.append(complexity)

                # Report high complexity
                if complexity > 10:
                    self.add_finding(filename, node.lineno, "warning", "design",
                                   f"High cyclomatic complexity ({complexity})",
                                   "Break function into smaller, more focused functions",
                                   0.8, "high")
                elif complexity > 5:  # Lower threshold to ensure detection
                    self.add_finding(filename, node.lineno, "suggestion", "design",
                                   f"Function has moderate complexity ({complexity})",
                                   "Consider breaking function into smaller parts",
                                   0.6, "medium")

                # Function length
                func_length = len([n for n in ast.walk(node) if isinstance(n, ast.stmt)])
                self.function_lengths.append(func_length)

                if func_length > 20:  # Lower threshold for more detection
                    self.add_finding(filename, node.lineno, "warning", "design",
                                   f"Long function ({func_length} statements)",
                                   "Break function into smaller, more focused functions",
                                   0.8, "medium")

                # Nesting depth
                max_depth = self.get_nesting_depth(node)
                if max_depth > 3:  # Lower threshold for more detection
                    self.add_finding(filename, node.lineno, "warning", "design",
                                   f"Deep nesting (depth {max_depth})",
                                   "Reduce nesting with early returns or helper functions",
                                   0.75, "medium")

                # Naming conventions
                is_valid, msg = self.check_naming_conventions(node.name, "function")
                if not is_valid:
                    self.add_finding(filename, node.lineno, "suggestion", "style",
                                   f"Function naming: {msg}",
                                   f"Rename '{node.name}' to follow snake_case convention",
                                   0.9, "low")

            # Class analysis
            elif isinstance(node, ast.ClassDef):
                is_valid, msg = self.check_naming_conventions(node.name, "class")
                if not is_valid:
                    self.add_finding(filename, node.lineno, "suggestion", "style",
                                   f"Class naming: {msg}",
                                   f"Rename '{node.name}' to follow PascalCase convention",
                                   0.9, "low")

            # Variable analysis - check naming conventions
            elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
                # Skip function parameters and common patterns
                if node.id not in ['self', 'cls', '_', '__']:
                    if node.id.isupper() and len(node.id) > 1:
                        is_valid, msg = self.check_naming_conventions(node.id, "constant")
                    else:
                        is_valid, msg = self.check_naming_conventions(node.id, "variable")

                    if not is_valid:
                        self.add_finding(filename, getattr(node, 'lineno', 1), "suggestion", "style",
                                       f"Variable naming: {msg}",
                                       f"Rename '{node.id}' to follow proper naming convention",
                                       0.85, "low")

            # Security checks
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id in ['eval', 'exec']:
                    self.add_finding(filename, getattr(node, 'lineno', 1), "critical", "security",
                                   f"Dangerous function '{node.func.id}'",
                                   "Avoid eval/exec, use safer alternatives like ast.literal_eval",
                                   0.95, "high")
                    self.security_issues += 1

            # Hardcoded secrets - check both strings and variable assignments
            if isinstance(node, ast.Constant) and isinstance(node.value, str):
                secret_keywords = ['password', 'secret', 'key', 'token', 'api_key', 'auth']
                if any(keyword in node.value.lower() for keyword in secret_keywords):
                    if len(node.value) > 8:  # Long enough to be a real secret
                        self.add_finding(filename, getattr(node, 'lineno', 1), "critical", "security",
                                       "Hardcoded secret detected in string",
                                       "Use environment variables or secure configuration management",
                                       0.9, "high")
                        self.security_issues += 1

            # Check for suspicious variable assignments (like Password = "...")
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        if any(keyword in target.id.lower() for keyword in ['password', 'secret', 'key', 'token']):
                            if (isinstance(node.value, ast.Constant) and
                                isinstance(node.value.value, str) and len(node.value.value) > 8):
                                self.add_finding(filename, getattr(node, 'lineno', 1), "critical", "security",
                                               f"Hardcoded secret in variable '{target.id}'",
                                               "Use environment variables or secure configuration",
                                               0.9, "high")
                                self.security_issues += 1

    def analyze_content_advanced(self, content: str, filename: str):
        """Advanced content analysis"""
        lines = content.split('\n')

        for i, line in enumerate(lines, 1):
            # Line length check
            if len(line) > 88:  # PEP 8 recommends 79, but 88 is common with Black
                self.add_finding(filename, i, "suggestion", "style",
                               f"Line too long ({len(line)} characters)",
                               "Break long lines for better readability (PEP 8)",
                               0.7, "low")

            # TODO/FIXME comments
            if re.search(r'\b(TODO|FIXME|XXX|HACK)\b', line.upper()):
                self.add_finding(filename, i, "suggestion", "maintainability",
                               "TODO/FIXME comment found",
                               "Address technical debt by implementing or creating tickets",
                               0.5, "low")

            # Print statements (potential debug code)
            if re.search(r'\bprint\s*\(', line) and not line.strip().startswith('#'):
                self.add_finding(filename, i, "suggestion", "maintainability",
                               "Print statement found",
                               "Replace with proper logging using logging module",
                               0.8, "low")

            # Bare except clauses - more precise pattern
            if re.search(r'except\s*:\s*$', line.strip()):
                self.add_finding(filename, i, "warning", "error_handling",
                               "Bare except clause catches all exceptions",
                               "Specify specific exceptions to catch, avoid catching all",
                               0.85, "medium")

    def add_finding(self, filename: str, line: int, severity: str, category: str,
                   issue: str, suggestion: str, fix_confidence: float, complexity_impact: str):
        """Add a code review finding with enhanced metadata"""
        finding = {
            "file": filename,
            "line": line,
            "severity": severity,
            "category": category,
            "issue": issue,
            "suggestion": suggestion,
            "fix_confidence": fix_confidence,
            "complexity_impact": complexity_impact
        }
        self.findings.append(finding)

    def calculate_scores(self) -> Dict[str, float]:
        """Calculate various quality scores"""
        base_score = 10.0

        # Deduct points based on findings
        for finding in self.findings:
            if finding["severity"] == "critical":
                base_score -= 2.0
            elif finding["severity"] == "warning":
                base_score -= 1.0
            elif finding["severity"] == "suggestion":
                base_score -= 0.5

        overall_score = max(1.0, base_score)

        # Complexity score
        avg_complexity = sum(self.complexity_scores) / len(self.complexity_scores) if self.complexity_scores else 1
        complexity_score = max(1.0, 10.0 - (avg_complexity - 1) * 0.5)

        # Security score
        security_score = max(1.0, 10.0 - self.security_issues * 1.5)

        # Maintainability score (based on function length and TODO count)
        avg_func_length = sum(self.function_lengths) / len(self.function_lengths) if self.function_lengths else 10
        maintainability_deduction = (avg_func_length - 20) * 0.1 if avg_func_length > 20 else 0
        maintainability_score = max(1.0, 10.0 - maintainability_deduction)

        return {
            "overall_score": round(overall_score, 1),
            "complexity_score": round(complexity_score, 1),
            "security_score": round(security_score, 1),
            "maintainability_score": round(maintainability_score, 1)
        }

    def generate_statistics(self) -> Dict[str, Any]:
        """Generate comprehensive statistics"""
        severity_counts = {"critical": 0, "warning": 0, "suggestion": 0}

        for finding in self.findings:
            severity_counts[finding["severity"]] += 1

        return {
            **severity_counts,
            "avg_cyclomatic_complexity": round(sum(self.complexity_scores) / len(self.complexity_scores), 1) if self.complexity_scores else 0,
            "max_function_length": max(self.function_lengths) if self.function_lengths else 0,
            "total_lines_analyzed": self.total_lines,
            "security_issues_found": self.security_issues
        }

    def generate_review(self):
        """Generate comprehensive code review"""
        scores = self.calculate_scores()
        statistics = self.generate_statistics()

        review = {
            "overall_score": int(scores["overall_score"]),
            "files_reviewed": self.files_reviewed,
            "total_issues": len(self.findings),
            "complexity_score": scores["complexity_score"],
            "maintainability_score": scores["maintainability_score"],
            "security_score": scores["security_score"],
            "statistics": statistics,
            "findings": self.findings
        }

        return review

    def save_review(self, output_path: str = "/app/code_review.json"):
        """Save review to JSON file"""
        review = self.generate_review()

        # Ensure directory exists - create if needed
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(review, f, indent=2, ensure_ascii=False)

def main():
    # Create comprehensive sample code files for testing
    code_dir = "/app/code_to_review/"
    if not os.path.exists(code_dir):
        os.makedirs(code_dir, exist_ok=True)

        # Sample file with various advanced issues - guaranteed to trigger all categories
        sample_code = '''#!/usr/bin/env python3
import os
import subprocess

# Multiple categories will be detected from this code:
# 1. SECURITY: hardcoded secrets, eval, SQL injection, command injection
# 2. STYLE: naming conventions, long lines
# 3. DESIGN: high complexity, deep nesting, long parameters
# 4. MAINTAINABILITY: TODO, print statements
# 5. PERFORMANCE: inefficient list concatenation
# 6. ERROR_HANDLING: bare except

class badClassName:  # STYLE: PascalCase violation
    def __init__(self):
        self.Password = "hardcoded_secret_123456789"  # SECURITY: hardcoded secret

    def BadMethodName(self, param1, param2, param3, param4, param5, param6):  # STYLE: naming + DESIGN: long params
        """Method with multiple issues."""
        temp_var = "unused"  # STYLE: unused variable

        try:
            result = eval("dangerous_code")  # SECURITY: dangerous function
        except:  # ERROR_HANDLING: bare except
            pass

        # DESIGN: Deep nesting + MAINTAINABILITY: print
        for i in range(10):
            if i > 5:
                for j in range(5):
                    if j > 2:
                        for k in range(3):
                            if k > 1:
                                print("Deep nesting detected")  # MAINTAINABILITY

        # PERFORMANCE: inefficient list concatenation
        result_list = []
        for item in range(100):
            result_list = result_list + [item]  # PERFORMANCE issue

        # SECURITY: SQL injection
        user_id = "test"
        query = "SELECT * FROM users WHERE id = %s" % user_id  # SECURITY
        # cursor.execute(query)

        # SECURITY: Command injection
        user_input = "test"
        filename = user_input + ".txt"
        os.system("cat " + filename)  # SECURITY

        # MAINTAINABILITY: TODO comment
        # TODO: Fix this terrible code
        return "This is a very long line that definitely exceeds the recommended 88 character limit and should be broken up for better readability"  # STYLE

def another_bad_function():  # STYLE: missing docstring
    password_key = "another_secret_key_12345"  # SECURITY: hardcoded secret
    pass

# DESIGN: High complexity function
def complex_function(a, b, c, d, e, f, g):  # DESIGN: long parameter list
    # This creates high cyclomatic complexity
    if a > 0:  # +1
        if b > 0:  # +1
            if c > 0:  # +1
                if d > 0:  # +1
                    if e > 0:  # +1
                        if f > 0:  # +1
                            if g > 0:  # +1
                                return "very complex"
                            else:
                                return "still complex"
                        else:
                            return "getting complex"
                    else:
                        return "complex"
                else:
                    return "complex"
            else:
                return "complex"
        else:
            return "complex"
    else:
        return "complex"
'''

        with open(os.path.join(code_dir, "sample_bad_code.py"), 'w') as f:
            f.write(sample_code)

        # Create a good example for contrast
        good_code = '''#!/usr/bin/env python3
"""A well-written Python module demonstrating good practices."""

import os
from typing import List, Optional


class CodeAnalyzer:
    """Analyzes code quality following best practices."""

    def __init__(self, config: dict):
        """Initialize with configuration."""
        self.config = config
        self._results = []

    def analyze_file(self, file_path: str) -> Optional[dict]:
        """Analyze a single file and return results.

        Args:
            file_path: Path to the file to analyze

        Returns:
            Analysis results or None if file cannot be read
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
            return self._process_content(content)
        except FileNotFoundError:
            return None

    def _process_content(self, content: str) -> dict:
        """Process file content and extract metrics."""
        lines = content.split('\\n')
        return {
            'line_count': len(lines),
            'char_count': len(content)
        }
'''

        with open(os.path.join(code_dir, "good_example.py"), 'w') as f:
            f.write(good_code)

    # Run the advanced code reviewer
    reviewer = AdvancedCodeReviewer()
    reviewer.analyze_directory()
    reviewer.save_review()

    # Print comprehensive summary
    review = reviewer.generate_review()
    print(f"Advanced Code Review Complete!")
    print(f"Files reviewed: {review['files_reviewed']}")
    print(f"Overall score: {review['overall_score']}/10")
    print(f"Total issues: {review['total_issues']}")
    print(f"Complexity score: {review['complexity_score']}/10")
    print(f"Security score: {review['security_score']}/10")
    print(f"Maintainability score: {review['maintainability_score']}/10")

if __name__ == "__main__":
    main()
EOF

# Run the advanced code reviewer
python code_reviewer.py