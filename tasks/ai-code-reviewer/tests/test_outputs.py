import json
from pathlib import Path


def test_code_review_json_exists():
    """Test that code review JSON file is created"""
    review_path = Path("/app/code_review.json")
    assert review_path.exists(), "code_review.json should exist in /app"


def test_enhanced_json_structure():
    """Test that code review JSON has enhanced structure with all required fields"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Check required top-level fields
    required_fields = [
        "overall_score", "files_reviewed", "findings",
        "total_issues", "complexity_score", "maintainability_score",
        "security_score", "statistics"
    ]

    for field in required_fields:
        assert field in review, f"JSON should contain '{field}' field"

    # Validate data types
    assert isinstance(review["overall_score"], int), "overall_score should be integer"
    assert isinstance(review["files_reviewed"], int), "files_reviewed should be integer"
    assert isinstance(review["total_issues"], int), "total_issues should be integer"
    assert isinstance(review["complexity_score"], (int, float)), \
        "complexity_score should be numeric"
    assert isinstance(review["maintainability_score"], (int, float)), \
        "maintainability_score should be numeric"
    assert isinstance(review["security_score"], (int, float)), \
        "security_score should be numeric"
    assert isinstance(review["statistics"], dict), "statistics should be a dictionary"
    assert isinstance(review["findings"], list), "findings should be a list"


def test_statistics_structure():
    """Test that statistics section has required fields with correct types"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    statistics = review["statistics"]
    required_stats = [
        "critical", "warning", "suggestion",
        "avg_cyclomatic_complexity", "max_function_length"
    ]

    for stat in required_stats:
        assert stat in statistics, f"Statistics should contain '{stat}' field"

    # Validate stat types
    assert isinstance(statistics["critical"], int), "critical count should be integer"
    assert isinstance(statistics["warning"], int), "warning count should be integer"
    assert isinstance(statistics["suggestion"], int), \
        "suggestion count should be integer"
    assert isinstance(statistics["avg_cyclomatic_complexity"], (int, float)), \
        "avg_cyclomatic_complexity should be numeric"
    assert isinstance(statistics["max_function_length"], int), \
        "max_function_length should be integer"


def test_findings_structure():
    """Test that findings have correct structure with all required fields"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    findings = review["findings"]

    # Should have at least some findings from sample code
    assert len(findings) > 0, "Should detect at least some issues in sample code"

    # Check first finding has all required fields
    finding = findings[0]
    required_fields = [
        "file", "line", "severity", "category", "issue",
        "suggestion", "fix_confidence", "complexity_impact"
    ]

    for field in required_fields:
        assert field in finding, f"Finding should contain '{field}' field"

    # Validate field types
    assert isinstance(finding["file"], str), "file should be string"
    assert isinstance(finding["line"], int), "line should be integer"
    assert finding["line"] > 0, "line number should be positive"
    assert isinstance(finding["severity"], str), "severity should be string"
    assert isinstance(finding["category"], str), "category should be string"
    assert isinstance(finding["issue"], str), "issue should be string"
    assert isinstance(finding["suggestion"], str), "suggestion should be string"
    assert isinstance(finding["fix_confidence"], (int, float)), \
        "fix_confidence should be numeric"
    assert isinstance(finding["complexity_impact"], str), \
        "complexity_impact should be string"


def test_score_ranges():
    """Test that all scores are within valid ranges"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Overall score should be 1-10
    assert 1 <= review["overall_score"] <= 10, \
        f"overall_score should be 1-10, got {review['overall_score']}"

    # Other scores should be 1.0-10.0
    assert 1.0 <= review["complexity_score"] <= 10.0, \
        f"complexity_score should be 1.0-10.0, got {review['complexity_score']}"
    assert 1.0 <= review["maintainability_score"] <= 10.0, \
        f"maintainability_score should be 1.0-10.0, got \
            {review['maintainability_score']}"
    assert 1.0 <= review["security_score"] <= 10.0, \
        f"security_score should be 1.0-10.0, got {review['security_score']}"


def test_fix_confidence_range():
    """Test that fix confidence scores are within 0-1 range"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    for finding in review["findings"]:
        confidence = finding["fix_confidence"]
        assert 0.0 <= confidence <= 1.0, \
            f"fix_confidence should be 0.0-1.0, got {confidence} in finding: \
                {finding['issue']}"


def test_severity_values():
    """Test that severity values are valid"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    valid_severities = {"critical", "warning", "suggestion"}

    for finding in review["findings"]:
        assert finding["severity"] in valid_severities, \
            f"Invalid severity: {finding['severity']}"


def test_category_values():
    """Test that category values are valid"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    valid_categories = {
        "security", "performance", "design", "complexity", "style", "maintainability",
        "error_handling", "syntax", "file_access", "code_smell"
    }

    for finding in review["findings"]:
        assert finding["category"] in valid_categories, \
            f"Invalid category: {finding['category']}"


def test_complexity_impact_values():
    """Test that complexity_impact values are valid"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    valid_impacts = {"low", "medium", "high"}

    for finding in review["findings"]:
        assert finding["complexity_impact"] in valid_impacts, \
            f"Invalid complexity_impact: {finding['complexity_impact']}"


def test_detects_multiple_categories():
    """Test that reviewer detects issues across multiple categories"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    categories_found = set()
    for finding in review["findings"]:
        categories_found.add(finding["category"])

    # Should detect at least 2 different types of issues
    assert len(categories_found) >= 2, \
        f"Should detect multiple issue categories, found: {categories_found}"


def test_detects_security_issues():
    """Test that security vulnerabilities are detected"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    security_findings = [f for f in review["findings"] if f["category"] == "security"]

    # Sample code has multiple security issues
    assert len(security_findings) > 0, \
        "Should detect security vulnerabilities in sample code"


def test_detects_naming_issues():
    """Test that naming convention violations are detected"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Look for style category findings (which includes naming)
    style_findings = [f for f in review["findings"] if f["category"] == "style"]

    assert len(style_findings) > 0, \
        "Should detect naming/style convention violations"


def test_detects_design_issues():
    """Test that design/complexity issues are detected"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Accept both "design" and "complexity" categories
    design_findings = [
        f for f in review["findings"]
        if f["category"] in ["design", "complexity"]
    ]

    # Sample code has complexity and nesting issues
    assert len(design_findings) > 0, \
        "Should detect design/complexity issues (high \
            complexity, long functions, deep nesting)"


def test_total_issues_consistency():
    """Test that total_issues matches findings count"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    assert review["total_issues"] == len(review["findings"]), \
        f"total_issues ({review['total_issues']}) should match findings count \
            ({len(review['findings'])})"


def test_statistics_consistency():
    """Test that statistics counts match findings"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Count severities in findings
    severity_counts = {"critical": 0, "warning": 0, "suggestion": 0}
    for finding in review["findings"]:
        severity_counts[finding["severity"]] += 1

    # Should match statistics
    stats = review["statistics"]
    assert stats["critical"] == severity_counts["critical"], \
        f"Critical count mismatch: stats={stats['critical']}, \
            actual={severity_counts['critical']}"
    assert stats["warning"] == severity_counts["warning"], \
        f"Warning count mismatch: stats={stats['warning']}, \
            actual={severity_counts['warning']}"
    assert stats["suggestion"] == severity_counts["suggestion"], \
        f"Suggestion count mismatch: stats={stats['suggestion']}, \
            actual={severity_counts['suggestion']}"


def test_files_reviewed():
    """Test that files_reviewed count is correct"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    # Should have reviewed at least 1 file
    assert review["files_reviewed"] > 0, "Should review at least one Python file"

    # Count unique files in findings
    files_with_findings = set(f["file"] for f in review["findings"])

    # Files reviewed should be >= files with findings (some files might be clean)
    assert review["files_reviewed"] >= len(files_with_findings), \
        "files_reviewed should be >= unique files in findings"


def test_complexity_metrics():
    """Test that complexity metrics are calculated"""
    review_path = Path("/app/code_review.json")

    with open(review_path, 'r', encoding='utf-8') as f:
        review = json.load(f)

    stats = review["statistics"]

    # Should calculate complexity metrics if code was analyzed
    if review["files_reviewed"] > 0 and len(review["findings"]) > 0:
        assert stats["avg_cyclomatic_complexity"] >= 0, \
            "Should calculate average cyclomatic complexity"
        assert stats["max_function_length"] >= 0, \
            "Should track maximum function length"
