#!/usr/bin/env bash
# instruction-adapter.sh — shared derivation logic for instruction-only hosts.
#
# Instruction-only hosts (GitHub Copilot, Cline, Kiro, pi) load a single
# always-on rule file verbatim. That rule is DERIVED from the canonical
# repository AGENTS.md so every host sees the same guidance with no second
# source of truth. The derivation is:
#
#   <generated-by header>  +  verbatim AGENTS.md body
#
# Both install-plugin.sh (writer) and check-manifest.sh (drift guard) source
# this file so the expected body is computed in exactly ONE place. Any
# hand-edit of a generated adapter then diverges from what this function
# produces and is caught by the guard (R-8.3).

# The curated on-demand skill set mirrored into instruction-host skill copies,
# matching the subset install_cursor / install_windsurf already ship.
ADAPTER_ONDEMAND_SKILLS=(
  "uncle-dev-test-driven-development"
  "uncle-dev-incremental-implementation"
  "uncle-dev-code-review-and-quality"
)

# adapter_rule_header — the generated-by banner prepended to every always-on
# rule. It marks the file as derived and not-hand-editable so the drift guard's
# intent is documented in the artifact itself.
adapter_rule_header() {
  cat <<'EOF'
<!-- GENERATED — DO NOT EDIT.
     This always-on rule is derived from the canonical AGENTS.md at the
     uncle-dev repository root by scripts/install-plugin.sh. Edit AGENTS.md
     and re-run the installer instead. Hand-edits are rejected by
     scripts/check-manifest.sh (drift guard, R-8.3). -->
EOF
}

# adapter_rule_body <agents_md_path> — emit the exact derived always-on rule
# body for a given canonical AGENTS.md. This is the single definition of
# "AGENTS.md-derived content" used by both the writer and the guard.
adapter_rule_body() {
  local agents_md="$1"
  adapter_rule_header
  cat "$agents_md"
}
