# Acknowledge Workflow: ack / reject / supersede mechanics

Loaded by `uncle-dev-acknowledge` workflow mode. Covers the propagation algorithm, the lock around `_meta.yaml`, and the exact regex used for status-line rewrites. The capture flow lives in `SKILL.md`; this file is the operational manual for the four workflow commands.

## The four commands

| Command | What it does | Files touched |
|---|---|---|
| `ack <ids>` | Flips `status: pending` → `status: acknowledged`, stamps `ack_by` and `ack_at` | Every scope file containing each id |
| `reject <ids> --reason <r>` | Flips status → `rejected`, records reason | Every scope file containing each id |
| `supersede <old> --by <new>` | Marks old as `superseded`, sets `supersedes:` on new, sets `superseded_by:` on old | Every scope file containing the old id; new id must already exist (capture it first) |
| `list [--scope <s>] [--status <s>]` | Read-only summary | None |

`<ids>` is comma-separated: `D5,D6,D9`. Whitespace tolerated. Any unknown id is reported and skipped — partial success is allowed; the gate will simply still fire on the unknowns.

## Propagation across duplicates

A D-id can appear in multiple scope files (`api.md` and `share.md`, etc.). All copies share one global id; an ack on any copy must propagate to all. The algorithm:

1. **Resolve duplicates.** For id `D<N>`:
   - Read `openspec/acknowledge/_meta.yaml` to get the list of scopes (filenames without `.md`).
   - For each scope file, grep for `^<!-- decision-id: D<N> -->$`. Every file that matches is a copy.
   - Cross-check against the section's own `duplicated_in:` bullet — if it disagrees with the grep result, prefer the grep (the file system is the truth) but emit a warning so the human can fix the metadata.
2. **Apply the rewrite to every matching file.** Use the regex below. The rewrite is idempotent: re-acking an already-acked id is a no-op (it does NOT bump `ack_at`).
3. **Update `last_updated:` in each file's frontmatter** to today (UTC).

## Status-line rewrite regex

The bullets we modify always appear at the top of a section, on lines starting with `- `. We anchor on the bullet name to avoid matching prose.

For an ack on `D5` in a file:

```python
# Pseudocode — adapt to whatever scripting/sed/awk fits the runtime.
section = read_section(file, "D5")    # text from comment anchor to next ^### or EOF
section = re.sub(
    r"^- status:\s*\S+",
    "- status: acknowledged",
    section,
    count=1,
    flags=re.MULTILINE,
)
section = re.sub(
    r"^- ack_by:\s*\S.*$",
    f"- ack_by: {git_user_email}",
    section,
    count=1,
    flags=re.MULTILINE,
)
section = re.sub(
    r"^- ack_at:\s*\S.*$",
    f"- ack_at: {now_utc_iso8601}",
    section,
    count=1,
    flags=re.MULTILINE,
)
write_section(file, "D5", section)
```

Same shape for `reject` (also adds a new `- reject_reason: …` bullet if absent) and `supersede` (writes `- superseded_by: D<new>` on the old, `- supersedes: D<old>` on the new).

**Hard rule:** the rewrite MUST NOT touch any line outside the metadata bullet block (the contiguous `- ` lines immediately under the heading). The prose body — every line after the first blank line following the bullets — is byte-identical before and after.

## Lock around `_meta.yaml`

Every workflow operation that reads `_meta.yaml` and would write back (only `supersede` does, and capture mode does for D-id allocation) acquires the same sentinel lock as `skills/uncle-dev-next-task/parallelism-and-locks.md`:

```bash
SENTINEL="openspec/acknowledge/_meta.yaml.acquiring"
TIMEOUT=30  # seconds; acks shouldn't have to wait long
ELAPSED=0

while ! mkdir "$SENTINEL" 2>/dev/null; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: could not acquire _meta.yaml lock after ${TIMEOUT}s — another agent may be stuck"
    echo "Inspect: ls -la openspec/acknowledge/_meta.yaml.acquiring/"
    exit 1
  fi
done

# critical section: read, mutate, write _meta.yaml

rmdir "$SENTINEL"
```

`ack`, `reject`, and `list` do NOT need the lock (they don't modify `_meta.yaml`). They DO need to be tolerant of `_meta.yaml` being briefly absent or mid-write — re-read once if a parse error happens.

## Required git config

`ack` refuses to write without `git config user.email`. If empty, the command exits with:

```
ERROR: cannot acknowledge without git user.email.
Set it with: git config --global user.email "<your-email>"
```

`reject` has the same requirement (the rejecter is recorded in a `- rejected_by:` bullet, mirroring `ack_by`).

## Idempotency

| Operation | Re-running on already-final state |
|---|---|
| `ack D5` when D5 is already acknowledged | No-op. `ack_at` is NOT bumped. Message: `D5 already acknowledged on 2026-05-09 by <email>`. |
| `ack D5` when D5 is rejected or superseded | Refuse. Message: `D5 is rejected/superseded; cannot ack. Use supersede to overturn.` |
| `reject D5` when D5 is already rejected | No-op. Reason NOT changed unless `--reason` differs and `--force` is passed. |
| `supersede D5 --by D8` when D5 is already superseded by D8 | No-op. |
| `supersede D5 --by D8` when D5 is already superseded by something else | Refuse with the conflict. |

## Removing notes

There is no `delete` command. Notes accumulate as history. To revoke an ack, use `reject` (records *why* it was revoked). To replace a decision, use `supersede` (links old → new). Hand-deletion is allowed but discouraged; the gate doesn't care about deleted sections, but humans grep for them later.

## Output format

After any workflow operation, print:

```
Acknowledged 3 decisions:
  D5  → api.md, general.md          (ack_by: javierhbr@gmail.com)
  D6  → api.md
  D9  → api.md, share.md

Skipped 1:
  D7  → not found in any scope file
```

This is the human's verification. The gate will use `list --status pending` next time `/uncle-dev-build` runs to confirm the gate clears.

## Failure modes

| Failure | Behavior |
|---|---|
| `_meta.yaml` lock not acquirable within 30s | Exit non-zero with the inspect command. Do not force the lock — it could be a long capture in flight. |
| Scope file present in `_meta.yaml` `scopes:` list but missing on disk | Warn, repair `_meta.yaml`, continue. |
| Scope file on disk but missing from `_meta.yaml` `scopes:` list | Warn, add to `_meta.yaml`, continue (after acquiring the lock). |
| D-id appears in a file's section but is missing from that file's `duplicated_in:` | Warn (capture-mode bug), proceed using grep results as truth. |
| Git user.email empty | Refuse to ack/reject. Print the fix. |
| Workflow rewrites the prose body (any line outside the bullet block) | This is a bug in the implementation. Fail loudly; do not write. |
