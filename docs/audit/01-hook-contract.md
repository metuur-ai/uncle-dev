# 01 — Rebuild the hook layer on one contract (P0)

## Problem

Of the 11 hook scripts wired in `hooks/hooks.json`, only 4 function as
designed (`session-start.sh`, `uncle-dev-mode.sh`, `gate-notify.sh`,
`permission-notify.sh`). The other 7 are inert or non-blocking because the
repo mixes **two input conventions** and **three output/block conventions**,
only one of each being the real Claude Code hook contract.

### Finding A — three guards read env vars Claude Code never sets (inert)

Claude Code delivers hook input as **JSON on stdin** (`.tool_name`,
`.tool_input.file_path`, `.tool_input.command`, …). No `CLAUDE_TOOL_*` env
vars exist. These scripts therefore always take their empty-input early exit
and **never fire**:

- `hooks/check-agents-md.sh:6` — `FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"`
- `hooks/openspec-guard.sh:11` — same pattern
- `hooks/spec-coherence-guard.sh:69,79,129,176` — `CLAUDE_TOOL_INPUT_file_path`,
  `CLAUDE_TOOL_INPUT_content`, `CLAUDE_TOOL_INPUT_new_string`,
  `CLAUDE_TOOL_INPUT_command`, and dispatch on `CLAUDE_TOOL_NAME` (empty →
  `*) exit 0`)

The flagship spec-coherence commit gate is one of the dead scripts. Evidence
the correct convention is already known in-repo: `pre-commit-guard.sh:17-18`,
`destructive-command-guard.sh:10-11`, `knowledge-capture-nudge.sh:11-23`,
`simplify-ignore.sh:26-31` all parse stdin JSON.

### Finding B — the two guards that do parse stdin block with the wrong exit code

PreToolUse contract: block with **`exit 2` + message on stderr**, or exit 0
with a recognized JSON decision on stdout (`{"decision":"block", ...}` /
`hookSpecificOutput.permissionDecision`). `exit 1` is a non-blocking error and
stdout is not shown to the model.

- `hooks/pre-commit-guard.sh:61` — "blocks" with `exit 1` + JSON on stdout
- `hooks/destructive-command-guard.sh:105` — same

Result: both guards are decorative. The commit / destructive command proceeds
and the message never reaches the model. Note `spec-coherence-guard.sh:49`
documents the correct contract ("stderr + exit 2 blocks the tool call") — the
repo is internally inconsistent about its own contract.

### Finding C — `{"priority","message"}` advisory schema is not a hook schema

On PreToolUse/PostToolUse/Stop, stdout on exit 0 is transcript-only. Advisory
messages emitted by `check-agents-md.sh:16-21`, `openspec-guard.sh:39-40`,
`knowledge-capture-nudge.sh:45`, `wrap-nudge.sh:93-96`, and the advisory
branches of both guards **never reach the model**. (For SessionStart and
UserPromptSubmit — `session-start.sh:66`, `uncle-dev-mode.sh:44` — raw stdout
IS injected as context, so those work; the JSON wrapper there is harmless
decoration.)

### Finding D — destructive-command-guard allowlist is trivially bypassable

`hooks/destructive-command-guard.sh:17-36`: glob patterns match the whole
command string, so chained commands pass the allowlist before destructive
checks run:

- `ls; rm -rf /` matches `ls*` → exit 0
- `git status && git push --force` matches `"git status "*`
- `ls*` also matches `lsof`, `lsblk`, …
- `sed *` is allowlisted although `sed -i` is destructive
- plain `rm file` matches **no** rm pattern (all require flags/leading space)

### Finding E — robustness issues in surviving hooks

- `hooks/session-start.sh:66` — uses `jq -n` with no `command -v jq` guard
  (every other jq-using hook guards). Missing jq → hook error on every
  session start.
- `hooks/hooks.json` — all 12 command strings use unquoted
  `${CLAUDE_PLUGIN_ROOT}` (e.g. line 8); breaks if the cache path ever
  contains spaces. Should be `bash "${CLAUDE_PLUGIN_ROOT}/hooks/…"`.
- `hooks/hooks.json:72` — Notification matcher `"permission_prompt"` is not a
  documented matcher value; verify against current Claude Code docs (either
  never matches or is ignored).
- `hooks/pre-commit-guard.sh:27-30` — message extraction only handles
  single-line `-m 'x'` / `-m "x"`; misses the heredoc style
  (`-m "$(cat <<'EOF' …)"`) that Claude Code itself uses.
- `hooks/gate-notify.sh:36-38` — concatenates all assistant text in the last
  200 transcript events; an earlier gate phrase can trigger a false
  notification after the gate passed.
- `hooks/wrap-nudge.sh:14` — dead `CONFIG_FILE` variable pointing directly at
  `.agents/uncle-dev-setup.yaml` (never used; near-miss on the config
  boundary; also false-positives boundary greps). Delete it.
- Executable bits inconsistent: `destructive-command-guard.sh`,
  `knowledge-capture-nudge.sh`, `openspec-guard.sh`, `pre-commit-guard.sh`
  are `-rw-r--r--` while the other 9 are executable (harmless — invoked via
  `bash` — but normalize).

## Change instructions

1. **Create `hooks/lib/hook-contract.sh`** with shared helpers:
   - `hook_read_input` — read stdin once into `HOOK_INPUT`; export
     `HOOK_TOOL_NAME=$(jq -r '.tool_name // empty')`,
     `HOOK_FILE_PATH=$(jq -r '.tool_input.file_path // empty')`,
     `HOOK_COMMAND=$(jq -r '.tool_input.command // empty')`,
     `HOOK_CONTENT`, `HOOK_NEW_STRING`. Guard with
     `command -v jq >/dev/null || exit 0`.
   - `hook_block "message"` — print message to **stderr**, `exit 2`.
   - `hook_advise "message"` — for PreToolUse/PostToolUse: emit
     `{"hookSpecificOutput":{"additionalContext":"…"}}` per current docs, or
     route via stderr+exit 2 only when truly blocking; never bare
     `{"priority","message"}`.
   - `hook_allow` — `exit 0` silently.
2. **Migrate the three inert scripts** (`check-agents-md.sh`,
   `openspec-guard.sh`, `spec-coherence-guard.sh`): source the lib, replace
   every `CLAUDE_TOOL_INPUT_*` / `CLAUDE_TOOL_NAME` read with the `HOOK_*`
   vars. Keep their logic otherwise unchanged.
3. **Fix the two wrong-exit guards** (`pre-commit-guard.sh:61`,
   `destructive-command-guard.sh:105`): replace `exit 1` + stdout JSON with
   `hook_block`. Advisory branches use `hook_advise`.
4. **Rework the destructive-guard allowlist**
   (`destructive-command-guard.sh:17-36`): reject or split on `;`, `&&`,
   `||`, `|`, `$(`, backticks before allowlist matching (evaluate each
   segment); anchor patterns (`ls*` → `ls` or `ls *`); remove `sed *` or
   special-case `sed -i`; add a pattern for bare `rm <path>`.
5. **Fix Finding E items**: jq guard in `session-start.sh`; quote
   `${CLAUDE_PLUGIN_ROOT}` in all `hooks.json` commands; verify/fix the
   Notification matcher; handle heredoc commit messages in
   `pre-commit-guard.sh` (or drop message-quality checks); scope
   `gate-notify.sh` to the *last* assistant message only; delete
   `wrap-nudge.sh:14`; `chmod +x` the four non-executable scripts.
6. **Add a contract smoke test** `hooks/tests/hook-contract-test.sh`: for each
   wired hook, pipe a synthetic tool-call JSON on stdin and assert
   (a) blocking cases exit 2 with non-empty stderr, (b) allow cases exit 0,
   (c) no script depends on `CLAUDE_TOOL_*` env vars
   (`grep -rn 'CLAUDE_TOOL' hooks/*.sh` returns empty after migration).
   Wire it into `scripts/tests/run-all.sh`.

## Expected result after

- `spec-coherence-guard`, `openspec-guard`, and `check-agents-md` actually
  fire on Write/Edit/Bash tool calls (today they never do).
- A `git commit` that violates the pre-commit gate is **actually blocked**
  and Claude sees the reason (today it proceeds silently).
- Destructive commands are blocked, including chained forms (`x && rm -rf y`).
- Nudge hooks (knowledge-capture, wrap) surface their messages to the model
  instead of the transcript void.
- `grep -rn 'CLAUDE_TOOL_INPUT' hooks/` → empty.
- New smoke test green in `scripts/tests/run-all.sh`.

## Verification

```bash
# inert-input pattern gone
grep -rn 'CLAUDE_TOOL' hooks/*.sh            # expect: no matches
# wrong block convention gone
grep -n 'exit 1' hooks/pre-commit-guard.sh hooks/destructive-command-guard.sh  # expect: none in block paths
# live block test
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' \
  | bash hooks/destructive-command-guard.sh; echo "exit=$?"   # expect exit=2, message on stderr
echo '{"tool_name":"Bash","tool_input":{"command":"ls; rm -rf /tmp/x"}}' \
  | bash hooks/destructive-command-guard.sh; echo "exit=$?"   # expect exit=2
bash scripts/tests/run-all.sh                                  # all suites + new hook contract suite green
```
