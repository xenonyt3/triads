![triads](assets/triads.webp)

# triads

Three OpenCode agents that split work by **risk of undetected harm**, not by difficulty.

- `helios` (primary): plans, splits work, routes each unit, reviews the results. Never edits code.
- `gaia` (subagent): does sensitive units.
- `selene` (subagent): does narrow, non-sensitive units.

## Why route by harm

A failure that is caught right away, like a red build or a failing test, only costs time. A failure that slips through quietly can cost money or leave an exploitable gap. So the worker is chosen by how bad a silent mistake would be, not by how hard the task looks.

## How routing works

Helios treats a unit as sensitive if it touches any of:

1. Authentication, authorization, sessions, permissions
2. Payments, pricing, money calculations, invoices
3. External input: forms, uploads, public APIs, webhooks, parsing external data
4. Secrets, credentials, env files, deployment config
5. Adding, removing, or upgrading dependencies
6. Data schemas, migrations, queries that modify data
7. Irreversible actions: deleting data, pushing, deploying

It judges by the surface touched (files, modules, functions), not by guessing whether the work will fail. When in doubt, it treats the unit as sensitive.

| Lane | Condition | Worker | Check |
|---|---|---|---|
| 1 | Sensitive | gaia | Helios reviews the diff line by line, plus a security scan |
| 2 | Not sensitive, failure is reliably caught (a relevant test, typecheck, or build exists) | selene | Worker's verification output + diff |
| 3 | Not sensitive, failure could pass silently | selene | Helios reviews the diff |

If Selene fails verification twice on the same unit, or reports NEEDS-ESCALATION, the unit moves to Gaia. If a Selene diff touches files outside its allowed list, or any file in a sensitive class, Helios rejects the result and gives the unit to Gaia. If Gaia is unavailable, Helios stops. A sensitive unit is never downgraded to Selene.

The full rules are in `agents/helios.md`.

## Requirements

- OpenCode >= 2.3 (V2 config: `agents/` folder, `permissions` rule lists, `model#variant`)
- Superpowers plugin (optional; Helios works with or without it)
- `git`
- A model provider configured in OpenCode for the three models you choose. API keys are not part of this repo.

## Install

Windows one-line:

```powershell
irm https://raw.githubusercontent.com/xenonyt3/triads/main/install.ps1 | iex
```

Linux/macOS one-line:

```bash
curl -fsSL https://raw.githubusercontent.com/xenonyt3/triads/main/install.sh | bash
```

From a clone:

```bash
git clone https://github.com/xenonyt3/triads.git
cd triads
pwsh ./install.ps1
```

On Linux/macOS, use `bash ./install.sh` instead of the last line. On Windows without PowerShell 7, run `powershell -ExecutionPolicy Bypass -File .\install.ps1` instead (Windows PowerShell 5.1 blocks local scripts by default).

The installer writes to `$OPENCODE_CONFIG_DIR/agents` if that variable is set, otherwise to `~/.config/opencode/agents`. It installs only `helios.md`, `gaia.md`, and `selene.md`. Files that are already identical are skipped. A changed file is backed up first as `<name>.md.bak-<yyyyMMdd-HHmmss>`. Downloaded files are validated before anything is written. The installer warns if the model provider is not configured, and warns (never deletes) if old `orchestrator.md`, `high-class.md`, or `low-class.md` files from an older version are still there.

## Choose your models

The agent files ship with the author's `9router` model ids; use your provider's id for the same model (run `opencode models` to list them).

<table>
<tr>
<td align="center" width="240"><img src="assets/helios.webp" width="220" alt="Helios"><br><sub><i>Sees everything. Touches nothing.</i></sub></td>
<td>Plans, splits work, routes each unit by risk, reviews every diff. Never edits code. Best overall in WorkflowArena: 36.95% resolved (max effort), 80.21 score (high effort). In the transfer test, where the planner writes the workflow but cannot touch the workspace (Helios's exact position), Opus-written workflows raised every one of four executor models: +6.41 points on average (static), +6.27 (dynamic). GPT-6 Astra, a strong coder on its own, averaged -2.53 / +1.34 in the same role: being good at the work is not the same as being good at organizing it.</td>
</tr>
<tr><td colspan="2"><b>Role:</b> <code>Planner, router and reviewer</code></td></tr>
<tr><td colspan="2"><b>Prompt:</b> <a href="agents/helios.md"><code>agents/helios.md</code></a></td></tr>
<tr><td colspan="2"><b>Recommended model:</b> <code>Claude Opus 5.5 (strongly advised)</code></td></tr>
<tr><td colspan="2"><b>Shipped as:</b> <code>9router/cc/claude-opus-5-5</code></td></tr>
</table>

<table>
<tr>
<td align="center" width="240"><img src="assets/gaia.webp" width="220" alt="Gaia"><br><sub><i>Holds what must not break.</i></sub></td>
<td>Does sensitive units: auth, money, external input, secrets, dependencies, schemas. A strong solo executor: 28.11% resolved / 76.12 score at medium, 30.80% / 77.69 at xhigh; shares the top Enterprise Operations result (27.78%, high effort). Its weak result as a planner (above) is why it works under Helios rather than in his place.</td>
</tr>
<tr><td colspan="2"><b>Role:</b> <code>Worker for sensitive units</code></td></tr>
<tr><td colspan="2"><b>Prompt:</b> <a href="agents/gaia.md"><code>agents/gaia.md</code></a></td></tr>
<tr><td colspan="2"><b>Recommended model:</b> <code>GPT-6 Astra (medium)</code></td></tr>
<tr><td colspan="2"><b>Shipped as:</b> <code>9router/cx/gpt-6-astra#medium</code></td></tr>
</table>

<table>
<tr>
<td align="center" width="240"><img src="assets/selene.webp" width="220" alt="Selene"><br><sub><i>Quiet work by night.</i></sub></td>
<td>Does narrow, non-sensitive units. Stops and reports if a unit turns out to be sensitive; Helios then hands it to Gaia. Weakest alone (6.08% resolved, 34.48 score), but it gained the most in relative terms from good orchestration: 18.37 &rarr; 25.24 with Opus dynamic workflows (+6.87, about +37%), while Astra static workflows dropped it to 12.85. Cheap worker + strong planner is the bet triads makes; Helios's routing keeps Selene away from anything where a silent mistake is costly.</td>
</tr>
<tr><td colspan="2"><b>Role:</b> <code>Worker for narrow, non-sensitive units</code></td></tr>
<tr><td colspan="2"><b>Prompt:</b> <a href="agents/selene.md"><code>agents/selene.md</code></a></td></tr>
<tr><td colspan="2"><b>Recommended model:</b> <code>DeepSeek V4.1 Flash</code></td></tr>
<tr><td colspan="2"><b>Shipped as:</b> <code>9router/ocg/deepseek-v4.1-flash</code></td></tr>
</table>

Numbers from [WorkflowArena: Benchmarking Executable Workflow Orchestration in LLM-Based Multi-Agent Systems](https://arxiv.org/abs/2611.12856) (Jiang et al., 2026), Table 1, Table 2 and the [project README](https://github.com/Einsia/WorkflowArena).

Caveats:

- The paper ran models in Claude Code and Codex, not OpenCode.
- Each configuration ran once per task, so there is no variance estimate.
- The paper's best Opus results used high/max effort. It does not measure cost, and "cheap" for Selene is the author's reason, not a paper result.

A model line uses `provider/model`, with an optional `#variant` (for example a reasoning level): `provider/model#variant`.

To apply a change, edit the `model:` line in `agents/helios.md`, `agents/gaia.md`, and `agents/selene.md` in a clone, then re-run the installer. You can also edit the installed copies in the install dir directly, but a later installer run will back those copies up and overwrite them.

## Use

Start OpenCode, switch to the `helios` agent, and describe the task.

To watch a worker: `Ctrl+X` then `Down` enters the first child session, `Left`/`Right` cycle children, `Up` returns to Helios.

## Uninstall

From a clone:

```powershell
pwsh ./install.ps1 -Uninstall
```

```bash
bash ./install.sh --uninstall
```

On Windows without PowerShell 7, run `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall` instead (Windows PowerShell 5.1 blocks local scripts by default).

Without a clone, Windows:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/xenonyt3/triads/main/install.ps1))) -Uninstall
```

Without a clone, Linux/macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/xenonyt3/triads/main/install.sh | bash -s -- --uninstall
```

Uninstall removes the three files and restores the newest backup for each, if one exists.

## Safety properties (verified on OpenCode 2.3.0)

- Helios `edit` is denied everywhere except `docs/superpowers/*` and `.superpowers/*`, including absolute paths, `../` traversal, and paths outside the project.
- Helios shell is deny-by-default; compound commands (`&&`, `;`) that start with an allowed prefix are still denied.
- Helios can dispatch only `gaia` and `selene`; `general` is denied.
- `deny` rules hold even under `--auto`.

Git rules (configured; loading verified, not yet tested by running each command):

- Helios may run `git add` and `git commit`. `git push` and `gh repo create` ask for confirmation.
- Force-push, `git reset --hard`, and `git clean` are denied.
- Gaia and Selene cannot push.

## Known limits

- "Stop if Gaia is unavailable" is a prompt rule, not an enforced mechanism.
- Helios cannot run tests or builds; it relies on worker reports plus the diff.
- The Superpowers SDD helper scripts are not runnable by Helios; it does their work manually (see the prompt).
- A `git push origin +branch` refspec force-push is not caught by the deny rules. It still asks for confirmation.

## License

MIT. See `LICENSE`.
