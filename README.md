# opencode-risk-router

Three OpenCode agents that route work by **risk of undetected harm**, not by difficulty.

| Agent | Mode | Model | Role |
|---|---|---|---|
| `orchestrator` | primary | `9router/cc/claude-opus-5-5` | Splits work, routes, reviews. Cannot edit code. |
| `high-class` | subagent | `9router/cx/gpt-6-astra#medium` | Sensitive units and escalations. |
| `low-class` | subagent | `9router/ocg/deepseek-v4.1-flash` | Narrow, non-sensitive units. |

Routing rules live in `agents/orchestrator.md`.

## Requirements (per device)
- OpenCode >= 2.3 (V2 config: `agents/` folder, `permissions` rule lists, `model#variant`)
- Superpowers plugin (optional; the orchestrator works with or without it)
- `git`
- A provider named `9router` exposing the three models above. API keys are not part of this repo.

## Install
Windows: `pwsh ./install.ps1`
Linux/macOS: `bash ./install.sh`

The installer copies `agents/*.md` to `~/.config/opencode/agents/`, backs up any
existing file with the same name, and checks that OpenCode loads all three agents.

## Use
Start OpenCode, switch to the `orchestrator` agent, describe the task.
Watch a worker: `Ctrl+X` then `Down` enters the first child session, `Left`/`Right`
cycle children, `Up` returns to the orchestrator.

## Swapping models
Edit the `model:` line in `agents/high-class.md` or `agents/low-class.md`, then
re-run the installer.

## Safety properties (verified on OpenCode 2.3.0)
- Orchestrator `edit` is denied everywhere except `docs/superpowers/*` and
  `.superpowers/*`, including absolute paths, `../` traversal, and paths outside
  the project.
- Orchestrator shell is deny-by-default; compound commands (`&&`, `;`) that
  start with an allowed prefix are still denied.
- Orchestrator can dispatch only `high-class` and `low-class`; `general` is denied.
- `deny` rules hold even under `--auto`.

## Known limits
- "Stop if high-class is unavailable" is a prompt rule, not an enforced mechanism.
- The orchestrator cannot run tests; it relies on worker reports plus the diff.
- The Superpowers SDD helper scripts are not runnable by the orchestrator; it
  does their work manually (see the prompt).
