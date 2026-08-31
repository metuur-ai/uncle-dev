#!/usr/bin/env bash
# Analyze codebase structure for Intent Layer placement
#
# Usage: ./analyze_structure.sh [path]                 # size + package boundaries (triggers 1-2)
#        ./analyze_structure.sh --criticality [path]   # responsibility/invariant scan (triggers 3-4)
#
# The two modes are PEERS, not a sequence. Size-based scanning systematically
# misses security-critical directories, which are typically small and dense.
# Run both before concluding the layer has no gaps.

set -e

if [ "$1" = "--criticality" ]; then
    CRITICALITY_MODE=1
    shift
else
    CRITICALITY_MODE=0
fi

TARGET_PATH="${1:-.}"

PRUNE='-not -path */node_modules/* -not -path */.git/* -not -path */dist/*
       -not -path */.next/* -not -path */build/* -not -path */__pycache__/*'

if [ "$CRITICALITY_MODE" = "1" ]; then
    echo "=== Criticality Scan (Step 3 triggers 3-4) ==="
    echo "Target: $TARGET_PATH"
    echo ""
    echo "Findings are UNRANKED BY SIZE and are HINTS, not verdicts."
    echo "Each one still has to be confirmed by reading the code."
    echo ""

    # --- Graph-backed signals (optional enrichment) ------------------------
    # When a graphify graph is present AND covers the target, edge centrality
    # beats every filesystem heuristic below: it cannot conflate same-named
    # directories, and community structure is the only real detector for
    # trigger 3. When absent or under-covered, the filesystem scan still runs.
    GRAPH=""
    for cand in "$TARGET_PATH/graphify-out/graph.json" "graphify-out/graph.json" \
                "$(git rev-parse --show-toplevel 2>/dev/null)/graphify-out/graph.json"; do
        [ -f "$cand" ] && { GRAPH="$cand"; break; }
    done

    if [ -n "$GRAPH" ] && command -v python3 >/dev/null 2>&1; then
        GRAPH_ROOT=$(dirname "$(dirname "$GRAPH")")
        REL="${TARGET_PATH#"$GRAPH_ROOT"/}"
        [ "$REL" = "$TARGET_PATH" ] && REL="${TARGET_PATH#./}"
        [ "$REL" = "." ] && REL=""
        echo "## Graph signals  ($GRAPH)"
        python3 "$(dirname "$0")/graph_criticality.py" "$GRAPH" \
            --root "$GRAPH_ROOT" --target "$REL" --top 20 || \
            echo "(graph unusable — filesystem signals below stand alone)"
        echo ""
    else
        if [ -z "$GRAPH" ]; then
            echo "## Graph signals: no graphify-out/graph.json — filesystem signals only"
        else
            echo "## Graph signals: python3 not found — filesystem signals only"
        fi
        echo ""
    fi

    echo "## Constraint density: high fan-in, low token count"
    echo "(importers per ~1k tokens — a directory many modules depend on but that"
    echo " is itself tiny is holding a constraint, not doing work)"
    echo ""
    echo "Caveat: import matching is by directory basename, so same-named directories"
    echo "(two 'types', two 'utils') inflate each other. Confirm the count before acting."
    echo ""
    printf "%-52s %8s %6s %7s\n" "DIRECTORY" "~tokens" "imports" "ratio"
    # shellcheck disable=SC2086
    find "$TARGET_PATH" -type d $PRUNE 2>/dev/null | while read -r dir; do
        [ "$dir" = "$TARGET_PATH" ] && continue
        base=$(basename "$dir")
        case "$base" in .*|test|tests|__tests__|fixtures|mocks) continue ;; esac

        bytes=$(find "$dir" -maxdepth 1 -type f \
            \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
            -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
            -o -name "*.rb" -o -name "*.kt" -o -name "*.swift" \) \
            -not -name "*.test.*" -not -name "*.spec.*" \
            -not -name "*_test.*" -not -name "test_*" \
            -exec cat {} + 2>/dev/null | wc -c | tr -d ' ')
        [ -z "$bytes" ] && bytes=0
        [ "$bytes" -lt 200 ] && continue
        tokens=$((bytes / 4))

        # How many files elsewhere in the tree import from this directory?
        if command -v rg >/dev/null 2>&1; then
            imports=$(rg -l --no-messages \
                "(from|require\(|import)\s*['\"][^'\"]*/${base}(/|['\"])" \
                "$TARGET_PATH" 2>/dev/null | grep -vc "^${dir}/" || true)
        else
            imports=$(grep -rl --exclude-dir=node_modules --exclude-dir=.git \
                -E "(from|require\(|import)[[:space:]]*['\"][^'\"]*/${base}(/|['\"])" \
                "$TARGET_PATH" 2>/dev/null | grep -vc "^${dir}/" || true)
        fi
        [ -z "$imports" ] && imports=0
        [ "$imports" -lt 3 ] && continue

        # importers per 1k tokens, scaled x10 for integer sort
        ratio=$(( imports * 10000 / (tokens + 1) ))
        printf "%-52s %8s %6s %7s\n" "$dir" "$tokens" "$imports" "$ratio"
    done | sort -k4 -rn | head -20

    echo ""
    echo "## Singleton exports (a second instance would diverge silently)"
    grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
        --include=*.ts --include=*.tsx --include=*.js --include=*.go \
        --include=*.py --include=*.rb \
        -E "^export const [a-zA-Z_]+ = new " "$TARGET_PATH" 2>/dev/null | head -20

    echo ""
    echo "## Invariants asserted in comments but not in types"
    grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
        --include=*.ts --include=*.tsx --include=*.js --include=*.go \
        --include=*.py --include=*.rb --include=*.java \
        -iE "^[[:space:]]*(//|#|\*)[[:space:]]*.*(single( [a-z-]+)? (source|impl|implementation|instance|point|place)|must (always|never)|do not (add|create|instantiate|import)|only (place|impl|instance)|never (add|create|bypass)|invariant)" \
        "$TARGET_PATH" 2>/dev/null | head -20

    echo ""
    echo "## Sole registration / composition points"
    echo "(directories whose entire non-test content is one file)"
    # shellcheck disable=SC2086
    find "$TARGET_PATH" -type d $PRUNE 2>/dev/null | while read -r dir; do
        n=$(find "$dir" -maxdepth 1 -type f \
            \( -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.py" \) \
            -not -name "*.test.*" -not -name "*.spec.*" -not -name "*_test.*" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$n" = "1" ]; then
            find "$dir" -maxdepth 1 -type f \
                \( -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.py" \) \
                -not -name "*.test.*" -not -name "*.spec.*" -not -name "*_test.*" 2>/dev/null
        fi
    done | head -20

    echo ""
    echo "## Test suites named for a cross-cutting property"
    echo "(a dedicated suite implies an invariant worth stating in a node)"
    find "$TARGET_PATH" -type f $PRUNE \
        \( -name "*test*" -o -name "*spec*" \) 2>/dev/null \
        | grep -iE "(tenant|isolation|permission|authz|access-control|rbac|leak|boundary)" \
        | head -15

    echo ""
    echo "A hit here earns a node ONLY if the invariant is not already stated by an"
    echo "ancestor node. Read the ancestor before creating a child — restating a parent"
    echo "is the failure mode on the other side of this one."
    exit 0
fi

echo "=== Intent Layer Structure Analysis ==="
echo "Target: $TARGET_PATH"
echo ""

echo "## Directory Structure (depth 3)"
find "$TARGET_PATH" -type d -maxdepth 3 \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/.next/*" \
  -not -path "*/build/*" \
  -not -path "*/__pycache__/*" \
  | head -50

echo ""
echo "## Existing Intent Nodes"
find "$TARGET_PATH" -name "AGENTS.md" -o -name "CLAUDE.md" 2>/dev/null | head -20

echo ""
echo "## Large Directories (potential boundaries)"
echo "(Directories with >9 non-test files — test files excluded so a directory"
echo " is not inflated past the line by its own test suite)"
find "$TARGET_PATH" -type d \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/.next/*" \
  -not -path "*/__tests__/*" \
  -exec sh -c 'count=$(find "$1" -maxdepth 1 -type f \
      -not -name "*.test.*" -not -name "*.spec.*" \
      -not -name "*_test.*" -not -name "test_*" \
      -not -name "*.snap" 2>/dev/null | wc -l); \
    [ "$count" -gt 9 ] && echo "$count files: $1"' _ {} \; 2>/dev/null \
  | sort -rn | head -25

echo ""
echo "## Package/Config Files (semantic boundaries)"
find "$TARGET_PATH" -maxdepth 4 \
  \( -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" -o -name "pyproject.toml" \) \
  -not -path "*/node_modules/*" 2>/dev/null | head -20

echo ""
echo "## Node Candidates (NOT recommendations — measure before creating)"
echo "Root context file: $TARGET_PATH/ (CLAUDE.md or AGENTS.md, one of them)"

# Find src-like directories
for dir in src lib app packages services api; do
  if [ -d "$TARGET_PATH/$dir" ]; then
    echo "Candidate: $TARGET_PATH/$dir"
  fi
done

echo ""
echo "A candidate earns an AGENTS.md if it meets ANY trigger in SKILL.md Mode A Step 3:"
echo "  >=20k tokens, package/module root, responsibility shift, or hidden invariants."
echo ""
echo "This scan covered triggers 1-2 only. It cannot see triggers 3-4, and the"
echo "directories that meet those are usually too small to appear above."
echo "Run BOTH before concluding there are no gaps:"
echo "  estimate_tokens.sh <candidate>              # trigger 1"
echo "  analyze_structure.sh --criticality $TARGET_PATH   # triggers 3-4"
