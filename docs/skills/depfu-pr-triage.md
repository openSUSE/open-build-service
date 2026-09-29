# depfu-pr-triage

## Overview

This document describes the two-phase workflow for reviewing open depfu PRs. In Phase 1, collect data and produce a report. In Phase 2, act on the PRs the team selects. Always complete Phase 1 before Phase 2.

## Phase 1: Triage

### Data Collection

Run these commands in parallel:

```bash
gh pr list --label depfu --state open --json number,title,body,isDraft --limit 50
```

Then for each PR:

```bash
gh pr view <N> --json title,body,statusCheckRollup
```

Do not merge a draft PR (`isDraft: true`). Note draft PRs in the report and skip them.

### Assessment Dimensions

Evaluate each PR across five dimensions.

**Security**
- Check whether the body contains a `Security Advisories` section.
- Extract CVE/GHSA identifiers and the attack type (XSS, injection, bypass, etc.).
- Classify the impact as **Universal** (default configuration affected) or **Conditional** (only specific configurations affected).

**Breaking Changes**
- Scan changelog entries for removed APIs, renamed methods, and positional-to-keyword argument changes.
- Flag any transitive dependency that crossed a major version boundary (for example, `connection_pool` 2 to 3).

**Importance**

Use this order: security fix > direct runtime dependency > indirect runtime dependency > tooling or development dependency.

**Urgency**
- Security CVE: **High**
- Runtime dependency with CI failures: **Medium**
- Tooling or development dependency with green CI: **Low**

**CI**

Classify CI as one of:
- **All green** - every check passed.
- **Failing** - one or more checks failed.

Do not merge a PR with any failing check. This rule has no exceptions. A failing check means the verdict is **Investigate**. The team decides when to proceed after it resolves all failures.

### Report Structure

Present the findings in three sections. Use a Markdown table for each section. Always present the sections in this order.

#### 1. Security Fixes

List all PRs that fix one or more CVEs or GHSAs here, regardless of CI status.

| PR | Branch | Gem | Change | CVEs/GHSAs | Attack Type | Impact | CI | Verdict |
|----|--------|-----|--------|------------|-------------|--------|----|---------|
| ... | ... | ... | ... | ... | ... | Conditional / Universal | All green / Failing | **Merge** / **Investigate** |

Verdict is **Merge** when all checks are green. Verdict is **Investigate** when any check fails.

#### 2. Mergeable - No Breaking Changes

List PRs that meet all of the following conditions:
- No security advisories (those go in section 1).
- Every CI check is green.
- No breaking changes in any dependency, direct or transitive.
- No transitive dependency crossed a major version boundary.

| PR | Branch | Gem | Change | CI | Verdict |
|----|--------|-----|--------|----|---------|
| ... | ... | ... | ... | All green | **Merge** |

#### 3. Everything Else

List all remaining PRs here. This includes PRs with any failing CI check, breaking changes, major transitive version bumps, or draft status.

| PR | Branch | Gem | Change | Blocker | CI | Verdict |
|----|--------|-----|--------|---------|----|---------|
| ... | ... | ... | ... | ... | All green / Failing | **Hold** / **Investigate** |

- **Hold** - a transitive dependency crossed a major version boundary.
- **Investigate** - any check fails or the PR contains breaking changes. Do not merge until all checks pass.

Always include the `Branch` column. PRs targeting `master` and `2.10` follow different workflows. Distinguish them clearly in the report.

After you present the three tables, stop and wait for the team to select which PRs to act on. When asked about a specific PR, summarize that PR in detail before acting.

## Phase 2: Act

Only start Phase 2 after the team confirms which PRs to merge.

**Merge sequentially - one PR at a time.**

Merging multiple PRs in parallel causes a race condition. When the first merge lands, it updates the base branch. GitHub then rejects all in-flight merges. Wait for each merge to complete before you start the next one.

```bash
gh pr review <N> --approve
gh pr merge <N> --merge
# Wait for success, then start the next PR.
```

Always use the `--merge` strategy (merge commit). Do not use `--squash` or `--rebase`.
