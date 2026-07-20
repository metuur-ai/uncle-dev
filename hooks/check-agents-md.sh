#!/bin/bash
# code-context pre-edit hook — PreToolUse Edit|Write
# Reminds the agent to read AGENTS.md in the target directory before editing.
# Reads the file_path from the JSON tool input on stdin (Claude Code contract).

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

[ -z "$HOOK_FILE_PATH" ] && exit 0

DIR="$(dirname "$HOOK_FILE_PATH")"
AGENTS_MD="$DIR/AGENTS.md"

if [ -f "$AGENTS_MD" ]; then
  hook_advise "code-context: AGENTS.md exists for the directory you are about to edit.
Read it before making changes: $AGENTS_MD"
fi

exit 0
