# Task Benchmark Export

> **⚠️ READ-ONLY REPOSITORY**
> This repository is automatically generated and maintained by a GitHub Actions workflow.
> It is locked down and effectively read-only - Issues, PRs, and direct pushes are disabled.
> Updates are made exclusively through the export workflow.

This repository contains **3 tasks**.

## Contents

- `tasks/` - Task definitions with instructions and test cases (3 tasks)
- `logs/` - Execution logs from validation runs
- `delivery.csv` - Summary of all tasks with results

## Structure

Each task in `tasks/` contains:
- `instruction.md` - Task instructions
- `task.toml` - Task configuration (with versioned docker_image reference)
- `environment/` - Environment setup
- `tests/` - Test cases
- `solution/` - Solution files (if available)

Logs in `logs/` are organized by task and agent.

## Docker Images

All tasks reference Docker images tagged with the specific export version for reproducibility:
- Image tag: `pr-93`
- Commit SHA: `e008025`

This ensures the exported benchmark is atomic and versioned.

See `delivery.csv` for a complete overview of all tasks and their results.

## Tasks Included

- `ad-campaign-timeline`
- `ai-code-reviewer`
- `api-change-guard`
