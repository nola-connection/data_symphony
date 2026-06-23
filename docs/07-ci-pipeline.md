# CI Pipeline

## Overview

The Data Symphony project uses GitHub Actions to enforce code quality standards on every pull request. The CI pipeline runs the Elixir quality gates (formatting, linting, testing, and static analysis) with caching optimizations to keep build times fast.

## Quality Gates

The pipeline enforces four quality checks:

1. **Format** (`mix format --check-formatted`)
   - Ensures code follows the standard Elixir formatting style
   - Runs on every PR
   - Non-blocking if code has formatting issues, but blocks merge via status checks

2. **Credo** (`mix credo --strict`)
   - Static analysis for code quality issues
   - Configured with `.credo.exs` to enforce strict mode
   - Checks for common anti-patterns, consistency issues, and style violations

3. **Test** (`mix test`)
   - Runs the full test suite with PostgreSQL service
   - Validates all functionality works as expected
   - Must pass for any PR to merge

4. **Dialyzer** (`mix dialyzer`)
   - Static type analysis tool
   - Catches type-related bugs before runtime
   - Uses cached PLTs for fast execution

## Caching Strategy

Both `deps` and `_build` directories are cached across jobs, keyed on the `mix.lock` file. This ensures:
- Dependency downloads are reused across multiple CI runs
- Compiled modules don't need to be rebuilt if lockfile hasn't changed
- Much faster CI execution times (typically 1-2 minutes vs 5+ minutes cold)

Dialyzer PLTs (Persistent Lookup Tables) are cached separately in `priv/plts` to avoid the expensive initial analysis run.

## Required Status Checks

The main branch is protected with a GitHub ruleset that requires all four CI checks to pass before a PR can be merged. The ruleset enforces:
- Deletion protection on main
- Non-fast-forward protection
- All four required status checks with strict policy

This ensures code merged to main is always:
- Properly formatted
- Free of style/quality issues (per credo)
- Fully tested
- Statically type-safe (per dialyzer)

## Local Quality Gates

Before pushing, run the same quality gates locally to avoid PR rejections:

```bash
# Format check
mix format --check-formatted

# Linting
mix credo --strict

# Testing
mix test

# Type checking
mix dialyzer
```

Or apply formatting automatically:

```bash
mix format
```

## Pinned Versions

All CI jobs use the pinned Elixir and OTP versions from `.tool-versions`:
- **Elixir**: 1.15.8
- **OTP**: 25.3.2.21

This ensures CI results are reproducible and match local development environments.
