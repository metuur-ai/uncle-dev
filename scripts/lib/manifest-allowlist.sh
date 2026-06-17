#!/usr/bin/env bash
# Intentional-exclusion allowlist for the manifest drift guard (check-manifest.sh).
#
# Co-located with manifest.sh (the canonical source of truth). An entry here means:
# "this asset exists in the canonical root but is INTENTIONALLY excluded from a
# hand-maintained copy (marketplace.json / plugins/uncle-dev/commands / README counts),
# and here is the written reason."
#
# Format:
#   - ALLOWLIST_SKILLS:   bare skill directory names, e.g. "uncle-dev-experimental"
#                         (matches a dir under skills/<name>/SKILL.md). Excluded from
#                         marketplace.json's skills list AND the README skill count.
#   - ALLOWLIST_COMMANDS: command file names WITH the .md extension, e.g. "uncle-dev-foo.md"
#                         (matches commands/<name>.md). Excluded from
#                         plugins/uncle-dev/commands/ AND the README command count.
#
# Rules:
#   - Every entry MUST carry a one-line comment explaining WHY it is excluded.
#   - An empty array means "no intentional exclusions" — every canonical asset must
#     appear in every copy. This is the default and the desired steady state.
#   - The guard PRINTS the honored allowlist on every run so exclusions are visible,
#     never silent.

ALLOWLIST_SKILLS=(
  # (empty) — no skill is intentionally excluded from marketplace.json / README today.
)

ALLOWLIST_COMMANDS=(
  # (empty) — no command is intentionally excluded from plugins/uncle-dev/commands / README today.
)
