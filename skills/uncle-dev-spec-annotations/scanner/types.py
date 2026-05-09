"""Shared data types for the spec coherence scanner."""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class Annotation:
    """One @spec annotation found in a code or test file.

    Attributes:
        ids: Spec IDs cited in this annotation (e.g. ['AUTH-UI-001', 'AUTH-UI-002']).
        file: Repo-relative file path.
        line: 1-indexed line number of the comment.
        owner_kind: AST classification of the entity that follows the comment.
            One of: function | class | method | route | component | module | test | none | unknown.
            'none' = tree-sitter classified the next sibling and found no entry-point
                    (the annotation IS a helper — flagged in --strict).
            'unknown' = no AST classification was possible (regex fallback mode);
                       helper detection is disabled for this annotation.
        owner_name: Identifier of the owner entity, or '' when owner_kind == 'none'.
        is_test_file: Whether the file is classified as a test (path-based heuristic).
    """

    ids: List[str]
    file: str
    line: int
    owner_kind: str = "none"
    owner_name: str = ""
    is_test_file: bool = False


@dataclass
class SpecDef:
    """One EARS spec defined in docs/specs/*.md.

    Attributes:
        id: Stable spec ID (e.g. 'AUTH-UI-001').
        status: One of 'implemented' ([x]), 'gap' ([ ]), 'deferred' ([D]).
        title: The behavior statement after the colon.
        source_file: Repo-relative path to the spec file.
        source_line: 1-indexed line number where the spec is defined.
    """

    id: str
    status: str
    title: str
    source_file: str
    source_line: int
