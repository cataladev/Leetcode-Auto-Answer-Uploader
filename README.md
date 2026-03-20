# LeetCode Sync Automation

Cross-platform Elixir CLI/service for syncing newly solved LeetCode problems into a GitHub repository as one folder and one git commit per problem.

## Overview

This project polls a configurable LeetCode profile, detects newly solved problems, writes each solution into a filesystem-safe folder inside a target repository, and creates exactly one git commit per new problem:

- commit format: `Add LeetCode solution: <Problem Title>`
- one new problem -> one folder -> one commit -> one push attempt
- reruns are idempotent because the tool tracks local sync state and also writes a committed manifest inside the target solutions repository

The default user and target repository match your setup:

- LeetCode user: `cataladev`
- solutions repo: `https://github.com/cataladev/leetcode`

## Why Elixir

Elixir was chosen because it is a strong fit for a scheduler-friendly CLI that needs reliable process control, straightforward fault handling, clean module separation, and easy packaging as an escript. The runtime model is also a good fit for future extensions such as a daemonized watcher, richer retries, or parallel metadata fetches.

## Project Layout

```text
.
├── mix.exs
├── lib/leetcode_sync/
│   ├── cli.ex
│   ├── config.ex
│   ├── leetcode_client.ex
│   ├── git.ex
│   ├── solution_writer.ex
│   ├── state.ex
│   ├── sync.ex
│   └── ...
├── priv/
│   ├── automation/
│   │   ├── macos/
│   │   ├── linux/
│   │   └── windows/
│   └── templates/
├── scripts/
└── test/
```

## How It Works

1. Load `.env` and CLI overrides.
2. Acquire a local lock file to prevent concurrent runs.
3. Ensure the target repo exists locally, cloning it if needed.
4. Pull the latest target branch and push any previously committed-but-unpushed local commits.
5. Fetch recent accepted LeetCode submissions for the configured username.
6. Filter out problems already recorded in local state or the committed target-repo manifest.
7. For each new problem:
   - fetch question metadata
   - try to fetch the real submitted code if LeetCode auth is configured
   - otherwise generate a metadata-backed placeholder solution file
   - write the folder into the target repo
   - create exactly one git commit for that problem
   - push immediately by default
   - update local state

## Commit Behavior

Runtime behavior is strict:

- multiple new problems are never batched into one commit
- each problem is committed immediately after its folder is written
- the commit message is always `Add LeetCode solution: <Problem Title>`
- only new problems are committed
- if a push fails after the commit is created, the local state records the problem as processed with `pending_push` status so the next run can push the existing commit instead of duplicating it

Development behavior in this repository also follows milestone commits:

- initial scaffold
- Mix/env config
- LeetCode client
- sync/state/git integration
- automation setup
- tests
- README completion

## Requirements

- Elixir 1.16+
- Erlang/OTP compatible with your Elixir version
- git
- network access to `leetcode.com` and GitHub

## Setup

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

2. Update `.env` with your values.

3. Install dependencies:

   ```bash
   mix deps.get
   ```

4. Run a healthcheck:

   ```bash
   mix run -e "LeetCodeSync.CLI.main(System.argv())" -- --healthcheck
   ```

5. Run a dry-run:

   ```bash
   mix run -e "LeetCodeSync.CLI.main(System.argv())" -- --dry-run --verbose
   ```

6. Run a real sync:

   ```bash
   mix run -e "LeetCodeSync.CLI.main(System.argv())"
   ```

7. Optional: build an escript binary:

   ```bash
   mix escript.build
   ./leetcode_sync --healthcheck
   ```

## Environment Variables

Required or commonly used values:

- `LEETCODE_USERNAME`
- `TARGET_REPO_URL`
- `TARGET_REPO_LOCAL_PATH`
- `SOLUTION_FILE_EXTENSION`
- `GIT_BRANCH`
- `COMMIT_AUTHOR_NAME`
- `COMMIT_AUTHOR_EMAIL`

Optional behavior controls:

- `DRY_RUN`
- `VERBOSE`
- `RECENT_ACCEPTED_LIMIT`
- `SYNC_INTERVAL_MINUTES`
- `REQUEST_TIMEOUT_MS`
- `STATE_FILE_PATH`
- `LOCK_FILE_PATH`
- `PUSH_AFTER_EACH_COMMIT`
- `AUTO_CLONE_TARGET_REPO`
- `ALLOW_DIRTY_TARGET_REPO`
- `STOP_ON_PUSH_FAILURE`
- `GITHUB_TOKEN`

Optional LeetCode auth for real submitted code retrieval:

- `LEETCODE_SESSION`
- `LEETCODE_CSRF_TOKEN`
- `LEETCODE_AUTH_USERNAME`

Notes:

- `SOLUTION_FILE_EXTENSION=auto` uses the LeetCode submission language when code retrieval succeeds.
- if code retrieval is unavailable, the tool falls back to a placeholder `solution.<ext>` plus `problem.json` and `README.md`
- `GITHUB_TOKEN` is optional and is only used for authenticated HTTPS push/clone flows

## Running Examples

Healthcheck:

```bash
mix run -e "LeetCodeSync.CLI.main(System.argv())" -- --healthcheck
```

Dry-run:

```bash
mix run -e "LeetCodeSync.CLI.main(System.argv())" -- --dry-run --verbose
```

Backfill the most recent accepted submissions visible to the configured LeetCode query:

```bash
mix run -e "LeetCodeSync.CLI.main(System.argv())" -- --backfill 20
```

Normal sync:

```bash
mix run -e "LeetCodeSync.CLI.main(System.argv())"
```

The CLI is one-shot by design. Schedulers handle the repetition. `--once` is accepted for compatibility but behaves the same as the default single-run execution.

## Idempotency

Idempotency is enforced in two places:

- local state file, defaulting to `.data/state.json`
- committed target-repo manifest at `.leetcode-sync/solutions.json`

The tool also skips folder creation if the destination folder already exists in the target repo. This protects reruns even if the local state file is lost or the machine changes.

## Solution Folder Contents

Each synced problem folder contains:

- `solution.<ext>`
- `problem.json`
- `README.md`

The folder name is the LeetCode title sanitized for cross-platform filesystem compatibility.

## Automation Setup

### macOS

Primary mechanism: `launchd`

Included files:

- `priv/automation/macos/dev.cataladev.leetcode-sync.plist`
- `scripts/install_macos_launchd.sh`

Behavior:

- run at login/load
- run daily at 9:00 AM local time

Install:

```bash
./scripts/install_macos_launchd.sh
```

Useful commands:

```bash
launchctl print gui/$(id -u)/dev.cataladev.leetcode-sync
launchctl kickstart -k gui/$(id -u)/dev.cataladev.leetcode-sync
tail -f logs/launchd.out.log logs/launchd.err.log
```

This plist is preconfigured for:

- `/Users/carlos/Development/Leetcode Auto Answer Uploader`

If you move the project, update the plist and `scripts/run_sync.sh`.

### Linux

Two supported options are included.

Cron:

- file: `priv/automation/linux/leetcode-sync.cron`
- installer: `scripts/install_linux_cron.sh`
- behavior: daily at 9:00 AM plus `@reboot`

Install:

```bash
./scripts/install_linux_cron.sh
```

User systemd:

- files:
  - `priv/automation/linux/leetcode-sync.service`
  - `priv/automation/linux/leetcode-sync.timer`
- installer: `scripts/install_linux_systemd.sh`
- behavior:
  - one run at user login via the enabled user service
  - daily run at 9:00 AM via the timer

Install:

```bash
./scripts/install_linux_systemd.sh
```

Check status:

```bash
systemctl --user status leetcode-sync.service
systemctl --user status leetcode-sync.timer
```

### Windows

Primary mechanism: Task Scheduler

Included files:

- `scripts/install_windows_task.ps1`
- `priv/automation/windows/README.md`

Behavior:

- daily at 9:00 AM
- additional run at user logon

Setup:

1. Update `ProjectRoot` in `scripts/install_windows_task.ps1`.
2. Run PowerShell as the intended user.
3. Execute:

   ```powershell
   .\scripts\install_windows_task.ps1
   ```

## Updating The Tool

When you update this automation project:

1. pull the latest changes for this repository
2. run `mix deps.get`
3. rerun the installer for your scheduler if automation files changed
4. rerun `--healthcheck`

## Troubleshooting

`invalid username`

- the configured `LEETCODE_USERNAME` does not resolve to a public LeetCode user

`no new problems`

- the run was valid, but everything visible from the current LeetCode history query was already processed

`dirty target repo`

- the target solutions repository has local changes
- either commit/stash those changes or set `ALLOW_DIRTY_TARGET_REPO=true` if you explicitly want the automation to proceed anyway

`real submitted code was not retrieved`

- public LeetCode data does not expose source code
- set `LEETCODE_SESSION` and `LEETCODE_CSRF_TOKEN` for the same account as `LEETCODE_USERNAME`

`push failed after commit`

- the local commit is already created
- the state file records `pending_push`
- fix credentials/network and rerun; the next run pushes pending commits before processing new problems

`lock already held`

- another sync is running or the previous run exited unexpectedly
- confirm no sync process is active, then remove the lock file at `LOCK_FILE_PATH`

## Limitations

- LeetCode does not publicly expose submitted source code, so real solution retrieval requires authenticated session cookies.
- Public recent accepted submission history can be limited. If more problems are solved between runs than the visible recent window, older solves may not be discovered without a backfill run and/or authenticated access.
- The tool assumes the authenticated LeetCode session belongs to the same account as `LEETCODE_USERNAME` when `LEETCODE_AUTH_USERNAME` is set.
- Windows automation assets are included, but the repository path in the PowerShell installer is intentionally a placeholder and must be changed on that machine.

## Notes On Reliability

- Partial pre-commit failures roll back generated files before the run exits.
- Push failures after commit do not cause duplicate commits on the next run.
- The target repository gets its own committed manifest so the repo itself remains the source of truth if the local state file is lost.
