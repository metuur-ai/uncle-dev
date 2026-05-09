# Parallelism and Locks

Reference for the ready-set algorithm and the lock file format. Loaded by the picker; covers the parallelism model in detail.

## The Ready-Set Algorithm

```
Inputs:
  changes      = list of in-progress OpenSpec changes
  scratchpads  = list of .devlocal/<user>/<story-id>/scratchpad.md files
  locks        = list of .devlocal/_locks/<change-id>/<story-id>.lock files

Output:
  ready        = list of (change-id, story) ready to start
  blocked      = list of (story, blockers[]) — for diagnostic output
```

### Step 1: Flatten

Collect every story across every in-progress change into a single list. Each story carries:

```
{
  change_id, story_id, status, deps[], mutex, est, scratchpad?
}
```

### Step 2: Filter unchecked

Drop any story whose status is `complete`.

### Step 3: Resolve dependency graph

For each remaining story, check every `dep` in its `deps[]`:

- Local dep (`1.2`) → look up status in same change
- Cross-change dep (`auth-rework:1.2`) → look up status in named change
- Missing dep target → treat story as **blocked-broken**, surface a warning

A story is **dep-ready** when every dep resolves to status `complete`.

### Step 4: Apply mutex constraints

Build a set of "held mutexes" — every mutex tag currently locked by an in-flight story (one with an active lock file).

For each dep-ready story:

- If `story.mutex == none` → unaffected
- If `story.mutex` is in held mutexes → **mutex-blocked**
- Otherwise → still in the ready set

### Step 5: Apply lock filtering

Drop any story that already has an active, non-stale lock owned by another agent. (An agent's own locks don't filter itself out — that would prevent resuming after a crash.)

### Step 6: Result

The remaining stories form the **ready set**. Stories dropped at steps 3, 4, or 5 go into the **blocked** list with their blocker(s) annotated, for diagnostic output.

## Worked Example

`tasks.md` for change `PF-001`:

```
1.1 Schema migration            (deps: none)        (mutex: schema)   → complete
1.2 Seed data                   (deps: 1.1)         (mutex: schema)   → complete
1.3 Config loader               (deps: 1.1)         (mutex: config)   → pending
1.4 Logger middleware           (deps: 1.1)         (mutex: none)     → pending
1.5 Wire config to logger       (deps: 1.3, 1.4)    (mutex: none)     → pending
1.6 Audit log sink              (deps: 1.4)         (mutex: auth)     → pending
```

`tasks.md` for change `dashboard-refactor`:

```
2.1 Theme tokens                (deps: none)        (mutex: none)     → pending
2.2 Apply tokens to header      (deps: 2.1)         (mutex: none)     → pending
```

Active locks: none.
Held mutexes: none.

**Ready set:**
- `PF-001:1.3` (deps satisfied; mutex `config` available)
- `PF-001:1.4` (deps satisfied; no mutex)
- `dashboard-refactor:2.1` (no deps; no mutex)

**Blocked:**
- `PF-001:1.5` ← waits on `[1.3, 1.4]`
- `PF-001:1.6` ← waits on `[1.4]`
- `dashboard-refactor:2.2` ← waits on `[2.1]`

Now agent A claims `PF-001:1.3`. The lock file is created and the mutex `config` is held. The picker re-runs for agent B:

**Ready set (agent B):**
- `PF-001:1.4` (mutex none)
- `dashboard-refactor:2.1` (mutex none)

`PF-001:1.3` is filtered (locked by agent A). No story currently held has the `config` mutex, so nothing else is mutex-blocked. Agent B picks `1.4`. Now `1.4` is locked too.

A third call comes in. Held locks: `1.3`, `1.4`. Held mutexes: `config`. Ready set:

- `dashboard-refactor:2.1` (no mutex, no deps)

Even though `1.6` has its dep `1.4` not yet complete, the picker knows it's still blocked. And `1.5` waits on both `1.3` and `1.4`. So the only available work is in the other change. This is exactly the parallel-safe behavior we want.

## Lock File Format

Path: `.devlocal/_locks/<change-id>/<story-id>.lock`

Contents (YAML for human readability):

```yaml
agent: claude-opus-4-7
worktree: feature/auth
session_id: 2026-05-09T14-32-00-abc123
started_at: 2026-05-09T14:32:00Z
last_heartbeat: 2026-05-09T14:45:12Z
pid: 48211
host: macbook-pro.local
```

### Acquisition (atomic)

```bash
LOCK_DIR=".devlocal/_locks/${CHANGE_ID}"
LOCK_FILE="${LOCK_DIR}/${STORY_ID}.lock"

mkdir -p "$LOCK_DIR"

# Atomic create-or-fail using mkdir of a sentinel directory
SENTINEL="${LOCK_FILE}.acquiring"
if mkdir "$SENTINEL" 2>/dev/null; then
  # We won the race — write the actual lock
  cat > "$LOCK_FILE" <<EOF
agent: ${AGENT_NAME}
worktree: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-worktree")
session_id: ${SESSION_ID}
started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
last_heartbeat: $(date -u +%Y-%m-%dT%H:%M:%SZ)
pid: $$
host: $(hostname)
EOF
  rmdir "$SENTINEL"
  echo "acquired"
else
  echo "lost race"
  exit 1
fi
```

The `mkdir` of the sentinel is atomic on POSIX filesystems. After winning, the actual lock file is written and the sentinel removed. If two agents `mkdir` simultaneously, exactly one succeeds.

### Heartbeat

While the lock is held, the owning agent updates `last_heartbeat` every ~5 minutes. The picker considers a lock **stale** when `now - last_heartbeat > 4 hours`.

### Stale-Lock Recovery

When the picker sees a stale lock during ready-set computation:

1. It does NOT auto-release. Stale doesn't mean abandoned — could be a long compile, a paused session, etc.
2. It surfaces the stale lock in output:

   ```
   ⚠ Stale lock on PF-001:1.3 (agent claude-opus-4-7, last heartbeat 6h ago)
     Run: /uncle-dev-next-task --release PF-001:1.3 to free it
   ```

3. The story is treated as **locked** (filtered from ready set) until the user explicitly releases.

`--release` removes the lock file after a confirmation prompt:

```
Release lock on PF-001:1.3?
  Held by: claude-opus-4-7 (worktree: feature/auth)
  Started: 2026-05-09T14:32:00Z (8h ago)
  Last heartbeat: 6h ago

  [y] Release and let next picker claim it
  [n] Keep the lock
```

### Release on Completion

When a story is marked complete (the calling skill checks the box in `tasks.md` and commits), the lock file is deleted. The picker watches for this on every invocation; orphaned lock files for completed stories are auto-cleaned with a single-line notice.

### Release on Abandon

If the user explicitly abandons a story (`/uncle-dev-build abandon` or moves on without completing), the caller deletes the lock. If they just stop without telling anyone, the heartbeat staleness rule applies.

## Mutex Tag Conventions

Mutex tags are project-defined strings. The skill doesn't enforce specific tags, but recommends:

| Tag | When to use |
|---|---|
| `schema` | DB migrations, ORM schema files |
| `config` | Top-level config files (`package.json`, `tsconfig.json`, env files) |
| `auth` | Auth middleware, session management, token logic |
| `routing` | Top-level route registration |
| `ci` | `.github/workflows/`, deploy configs |

Project teams should document their mutex taxonomy in the change template or in `CLAUDE.md`. The skill surfaces unknown mutex tags but does not error — projects evolve their own.

## Conductor / Multi-Worktree Setups

When using Conductor (or any multi-worktree setup), `.devlocal/_locks/` should be **shared across worktrees**, not duplicated per worktree. Two patterns work:

1. **Symlink:** Each worktree contains a symlink `.devlocal/_locks → ../<main-repo>/.devlocal/_locks`
2. **Bind mount:** The worktree's `.devlocal/_locks/` is bind-mounted from the shared repo

Without sharing, two agents in two worktrees both see "no locks" and both claim the same story.

The skill detects this footgun: if `.devlocal/_locks/` is a regular directory inside a git worktree (not the main repo), it warns:

```
⚠ .devlocal/_locks/ appears to be local to this worktree.
  In multi-worktree setups, locks should be shared across worktrees.
  See parallelism-and-locks.md for symlink/bind-mount setup.
```

## Determinism Guarantee

Two independent picker calls, with the same `tasks.md` files and the same lock state, MUST return the same recommendation. This is achieved by:

- Stable sort on (most-descendants DESC, in-flight-scratchpad DESC, est ASC, doc-order ASC, change-id ASC, story-id ASC)
- Lock state read once per call, not re-read mid-ranking
- No randomness in tie-breakers

Determinism matters because two agents calling at the same moment will agree on the recommendation. They race only on lock acquisition, where exactly one wins.
