---
name: obs-rubocop-lint-loop
description: Use when fixing rubocop offenses on a depfu rubocop update PR in open-build-service, running rake dev:lint:all in docker and committing fixes one cop at a time until the linter is green or a non-autocorrectable offense is encountered.
---

# OBS Rubocop Lint Loop

## Before You Start: Read the Depfu Changelog

Before you run the linter for the first time, get the depfu PR body and read the changelog. This tells you which cops are likely to fail.

```bash
gh pr list --head <branch-name>   # find the PR number
gh pr view <number> --json body -q .body
```

**What to look for:**

- **New cops added** — these require either `Enabled: false` in `.rubocop_todo.yml` or code fixes.
- **Autocorrect safety changes** — entries like "Mark `Cop/Name` autocorrect as unsafe" mean those cops will not auto-fix anymore.

After you read the changelog, write a plan with two lists:

**Autocorrectable cops:**
- List each cop that is autocorrectable.

**Non-autocorrectable cops:**
- List each cop that needs manual fixes.
- Note any cops marked unsafe.

This plan guides the loop, but does not replace it. Always let the actual linter output drive what you fix.

## Overview

1. Run `dev:lint:rubocop:autocorrectable_cops` to get the full list of autocorrectable cops.
2. For each autocorrectable cop, run rubocop with `-A --only <Cop/Name>` and commit.
3. Run `rake dev:lint:all` to find any remaining non-autocorrectable offenses.
4. Report remaining offenses to the user and stop.

## Key Rules

- Do not use `--rm` with `docker container run` or `docker compose run` commands.
- Run all docker commands via `docker compose run frontend <cmd>`.
- Use the commit message format shown in the Commit Convention section for each cop you fix.

## Step 1 — List Autocorrectable Cops

Run the reporting task to get a ranked list of all autocorrectable cops:

```bash
docker compose run frontend bundle exec rake dev:lint:rubocop:autocorrectable_cops
```

This prints a list of autocorrectable cops sorted by offense count. Use this list to drive the fix loop in Step 2.

## Step 2 — Fix Each Autocorrectable Cop and Commit

For each cop in the autocorrectable list, run:

```bash
docker compose run frontend bundle exec rubocop -a --ignore_parent_exclusion --only <Cop/Name>
git add -A && git commit -m "Autocorrect <Cop/Name> cop

Assisted-by: <Tool>:<Model>"
```

Repeat for every cop in the list.

## Step 3 — Run the Full Linter

```bash
docker compose run frontend bundle exec rake dev:lint:all
```

If it passes: **done**.

If it fails, collect the remaining offense lines and report them to the user. Do not try to fix them. If the changelog analysis from Step 0 has notes for a reported cop (for example, it was newly added or its autocorrect was marked unsafe), include those notes with the offense. This helps the user understand what changed and why.

## Workflow

```
Run dev:lint:rubocop:autocorrectable_cops
       |
       v (get list of autocorrectable cops)
For each cop:
  Run rubocop -a --ignore_parent_exclusion --only <name>
  Commit "Autocorrect <Cop/Name> cop"
       |
       v (all correctable cops fixed & committed)
Run rake dev:lint:all
       |
       v
   Passes? ──yes──> Done ✓
       |
       no (non-autocorrectable offenses remain)
       v
 Report offenses to the user and stop
```

## Commit Convention

```
Autocorrect RSpec/MatchWithSimpleRegex cop

Assisted-by: <Tool>:<Model>
```
