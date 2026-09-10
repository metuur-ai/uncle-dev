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

    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    : > "$TMP/graph.txt"; : > "$TMP/fanin.txt"; : > "$TMP/singletons.txt"
    : > "$TMP/invariants.txt"; : > "$TMP/registration.txt"; : > "$TMP/xcutting.txt"

    # Existing nodes, for the coverage join at the end: everything under the
    # target, plus every ancestor above it. A hit inside a directory an ancestor
    # node already covers is not a gap -- but only reading that ancestor can
    # decide, which is why the join marks UNVERIFIED and never COVERED.
    {
        # shellcheck disable=SC2086
        find "$TARGET_PATH" $PRUNE -type f \( -name "AGENTS.md" -o -name "CLAUDE.md" \) 2>/dev/null
        up="$TARGET_PATH"
        while :; do
            parent=$(dirname "$up")
            if [ "$parent" = "$up" ]; then break; fi
            up="$parent"
            if [ -f "$up/AGENTS.md" ]; then echo "$up/AGENTS.md"; fi
            if [ -f "$up/CLAUDE.md" ]; then echo "$up/CLAUDE.md"; fi
            case "$up" in .|/) break ;; esac
        done
    } | sed 's|^\./||' | sort -u > "$TMP/nodes.txt"

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
            --root "$GRAPH_ROOT" --target "$REL" --top 20 > "$TMP/graph.txt" 2>&1 || \
            echo "(graph unusable — filesystem signals below stand alone)" > "$TMP/graph.txt"
        cat "$TMP/graph.txt"
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
    done | sort -k4 -rn | head -20 | tee "$TMP/fanin.txt"

    echo ""
    echo "## Singleton exports (a second instance would diverge silently)"
    grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
        --include=*.ts --include=*.tsx --include=*.js --include=*.go \
        --include=*.py --include=*.rb \
        -E "^export const [a-zA-Z_]+ = new " "$TARGET_PATH" 2>/dev/null | head -20 | tee "$TMP/singletons.txt"

    echo ""
    echo "## Invariants asserted in comments but not in types"
    grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
        --include=*.ts --include=*.tsx --include=*.js --include=*.go \
        --include=*.py --include=*.rb --include=*.java \
        -iE "^[[:space:]]*(//|#|\*)[[:space:]]*.*(single( [a-z-]+)? (source|impl|implementation|instance|point|place)|must (always|never)|do not (add|create|instantiate|import)|only (place|impl|instance)|never (add|create|bypass)|invariant)" \
        "$TARGET_PATH" 2>/dev/null | head -20 | tee "$TMP/invariants.txt"

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
    done | head -20 | tee "$TMP/registration.txt"

    echo ""
    echo "## Test suites named for a cross-cutting property"
    echo "(a dedicated suite implies an invariant worth stating in a node)"
    find "$TARGET_PATH" -type f $PRUNE \
        \( -name "*test*" -o -name "*spec*" \) 2>/dev/null \
        | grep -iE "(tenant|isolation|permission|authz|access-control|rbac|leak|boundary)" \
        | head -15 | tee "$TMP/xcutting.txt"

    echo ""
    echo "## Coverage join — which hits already have a node"
    echo "(the scan cannot read intent, so an ancestor node is never scored as"
    echo " coverage. UNVERIFIED means: open that node and check. Do not skip it —"
    echo " asserting the parent covers it is the failure on the other side.)"
    echo ""

    {
        # graph rows: constraint-dense (trigger 4) or boundary-crossing (trigger 3)
        awk 'NF>=6 && $2 ~ /^[0-9]+$/ && ($5+0 >= 10 || $6+0 >= 40) { print $1 }' \
            "$TMP/graph.txt" 2>/dev/null || true
        # filesystem fan-in rows above the density knee
        awk 'NF==4 && $4 ~ /^[0-9]+$/ && $4+0 >= 50 { print $1 }' \
            "$TMP/fanin.txt" 2>/dev/null || true
        # directories holding a singleton, a comment invariant, a sole
        # registration point, or a suite named for a cross-cutting property
        cut -d: -f1 "$TMP/singletons.txt" "$TMP/invariants.txt" 2>/dev/null \
            | xargs -n1 dirname 2>/dev/null || true
        xargs -n1 dirname < "$TMP/registration.txt" 2>/dev/null || true
        xargs -n1 dirname < "$TMP/xcutting.txt" 2>/dev/null || true
    } | sed 's|^\./||' | sort -u > "$TMP/candidates.raw"

    # Normalize before joining. Build output is never a candidate, and an
    # invariant belongs to the code it constrains, not to the suite that guards
    # it — so a hit inside a test tree is attributed to its nearest non-test
    # ancestor rather than proposing a node on the suite.
    while read -r raw; do
        if [ -z "$raw" ]; then continue; fi
        case "$raw" in
            */node_modules|*/node_modules/*|*/.git|*/.git/*|*/dist|*/dist/*) continue ;;
            */build|*/build/*|*/.next|*/.next/*|*/coverage|*/coverage/*) continue ;;
        esac
        dir="$raw"
        while :; do
            skip=0
            for seg in $(printf '%s' "$dir" | tr '/' ' '); do
                case "$seg" in
                    test|tests|__tests__|spec|specs|fixtures|mocks|step-definitions) skip=1 ;;
                esac
            done
            if [ "$skip" = "0" ]; then break; fi
            parent=$(dirname "$dir")
            if [ "$parent" = "$dir" ]; then break; fi
            dir="$parent"
        done
        if [ -d "$dir" ]; then echo "$dir"; fi
    done < "$TMP/candidates.raw" | sort -u > "$TMP/candidates.txt"

    : > "$TMP/gaps.txt"
    printf "%-46s %-34s %s\n" "DIRECTORY" "NEAREST NODE" "COVERED?"
    while read -r dir; do
        if [ -z "$dir" ] || [ ! -d "$dir" ]; then continue; fi

        bestnode=""; bestlen=0
        while read -r node; do
            if [ -z "$node" ]; then continue; fi
            nd=$(dirname "$node")
            match=0
            if [ "$nd" = "." ] || [ "$nd" = "/" ]; then
                match=1
            else
                case "$dir/" in "$nd"/*) match=1 ;; esac
            fi
            if [ "$match" = "1" ] && [ "${#nd}" -ge "$bestlen" ]; then
                bestnode="$node"; bestlen=${#nd}
            fi
        done < "$TMP/nodes.txt"

        if [ -f "$dir/AGENTS.md" ] || [ -f "$dir/CLAUDE.md" ]; then
            printf "%-46s %-34s %s\n" "$dir" "(own node)" "YES"
        elif [ -n "$bestnode" ]; then
            printf "%-46s %-34s %s\n" "$dir" "$bestnode" "UNVERIFIED"
            echo "$dir|$bestnode" >> "$TMP/gaps.txt"
        else
            printf "%-46s %-34s %s\n" "$dir" "(none)" "NO"
            echo "$dir|" >> "$TMP/gaps.txt"
        fi
    done < "$TMP/candidates.txt"

    echo ""
    if [ -s "$TMP/gaps.txt" ]; then
        echo "## GAPS — resolve each before calling the layer complete"
        while IFS='|' read -r dir node; do
            echo "  $dir"
            if [ -n "$node" ]; then
                echo "    -> read $node and confirm it states THIS directory's invariant."
                echo "       If it does not, this is a gap, not coverage."
            else
                echo "    -> no ancestor node at all. Create one here or at the package root."
            fi
        done < "$TMP/gaps.txt"
    elif [ -s "$TMP/candidates.txt" ]; then
        echo "## GAPS: none — every hit above sits in a directory with its own node"
    else
        echo "## GAPS: none — no criticality hits in this target."
        echo "   That is a finding about the scan, not a clean bill of health:"
        echo "   confirm the target actually holds source before trusting it."
    fi

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
