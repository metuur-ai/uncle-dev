"""Comment-aware regex extraction — fallback when tree-sitter is unavailable.

Per-language comment patterns. We extract comment spans first, then look for
@spec inside comments only. This avoids matching @spec inside string literals,
template literals, or code identifiers.

Owner classification is degraded in this mode (always 'none').
"""

import re
from typing import Dict, List, Tuple

from .types import Annotation

# @spec ID extraction within a comment string.
# Matches: "@spec AUTH-UI-001", "@spec AUTH-001, AUTH-002", "@spec AUTH-001  AUTH-002"
SPEC_ANNOTATION_RE = re.compile(
    r"@spec\s+([A-Z][A-Z0-9-]+(?:[\s,]+[A-Z][A-Z0-9-]+)*)"
)
ID_VALIDATE_RE = re.compile(r"^[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-\d+$")


# Per-language comment span patterns.
# Each pattern captures one full comment occurrence so we can preserve line offsets.
LANGUAGE_COMMENT_PATTERNS: Dict[str, List[str]] = {
    "c_style": [
        r"//[^\n]*",            # line comment
        r"/\*[\s\S]*?\*/",      # block comment
    ],
    "hash": [
        r"#[^\n]*",
    ],
    "html": [
        r"<!--[\s\S]*?-->",
    ],
}

EXT_TO_FAMILY: Dict[str, str] = {
    ".ts": "c_style",
    ".tsx": "c_style",
    ".js": "c_style",
    ".jsx": "c_style",
    ".mjs": "c_style",
    ".cjs": "c_style",
    ".go": "c_style",
    ".rs": "c_style",
    ".java": "c_style",
    ".kt": "c_style",
    ".swift": "c_style",
    ".c": "c_style",
    ".h": "c_style",
    ".cpp": "c_style",
    ".hpp": "c_style",
    ".cs": "c_style",
    ".scala": "c_style",
    ".py": "hash",
    ".rb": "hash",
    ".sh": "hash",
    ".bash": "hash",
    ".yml": "hash",
    ".yaml": "hash",
    ".toml": "hash",
    ".html": "html",
    ".htm": "html",
    ".vue": "html",
    ".svelte": "html",
}


def _extract_ids(comment_text: str) -> List[str]:
    ids: List[str] = []
    for match in SPEC_ANNOTATION_RE.finditer(comment_text):
        raw = match.group(1)
        for token in re.split(r"[\s,]+", raw):
            token = token.strip()
            if token and ID_VALIDATE_RE.match(token):
                ids.append(token)
            elif token:
                # Malformed ID — surface as a token starting with '!' for the
                # report layer to flag. Keeps the scanner deterministic.
                ids.append(f"!MALFORMED:{token}")
    return ids


def _line_of_offset(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def extract_annotations_regex(
    file_path: str, source: str, ext: str, is_test_file: bool
) -> List[Annotation]:
    """Extract @spec annotations from comments using language-aware regex.

    Returns one Annotation per comment that contains at least one @spec ID.
    Owner classification is always 'none' in this mode.
    """
    family = EXT_TO_FAMILY.get(ext.lower())
    if family is None:
        # Unknown extension — try all comment families combined.
        patterns = (
            LANGUAGE_COMMENT_PATTERNS["c_style"]
            + LANGUAGE_COMMENT_PATTERNS["hash"]
            + LANGUAGE_COMMENT_PATTERNS["html"]
        )
    else:
        patterns = LANGUAGE_COMMENT_PATTERNS[family]

    combined = "|".join(f"(?:{p})" for p in patterns)
    annotations: List[Annotation] = []

    for match in re.finditer(combined, source):
        comment = match.group(0)
        if "@spec" not in comment:
            continue
        ids = _extract_ids(comment)
        if not ids:
            continue
        annotations.append(
            Annotation(
                ids=ids,
                file=file_path,
                line=_line_of_offset(source, match.start()),
                owner_kind="unknown",
                owner_name="",
                is_test_file=is_test_file,
            )
        )

    return annotations
