"""Stdlib `ast` extraction for Python — zero-dep path with owner classification.

Used when tree-sitter is unavailable but we want owner_kind detection for .py.
Falls back to extract_regex if the file fails to parse (e.g. syntax error or Py2).
"""

import ast
import io
import tokenize
from typing import List, Optional

from .extract_regex import _extract_ids, extract_annotations_regex
from .types import Annotation


def _classify(node: ast.AST) -> tuple[str, str]:
    """Return (owner_kind, owner_name) for the first statement after a comment."""
    if isinstance(node, ast.FunctionDef):
        # Heuristic: test if name starts with 'test_' or is decorated with @pytest etc.
        if node.name.startswith("test_"):
            return "test", node.name
        return "function", node.name
    if isinstance(node, ast.AsyncFunctionDef):
        if node.name.startswith("test_"):
            return "test", node.name
        return "function", node.name
    if isinstance(node, ast.ClassDef):
        return "class", node.name
    if isinstance(node, ast.Assign):
        # @app.route('/x') style decorators apply to the next def, not assignments.
        # Plain assignments are not entry points.
        return "none", ""
    return "none", ""


def _find_owner_after_line(tree: ast.AST, line: int) -> tuple[str, str]:
    """Find the first AST node on or after `line` and classify it."""
    candidates: list[tuple[int, ast.AST]] = []
    for node in ast.walk(tree):
        node_line = getattr(node, "lineno", None)
        if node_line is None:
            continue
        if node_line >= line and isinstance(
            node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
        ):
            candidates.append((node_line, node))
    if not candidates:
        return "none", ""
    candidates.sort(key=lambda x: x[0])
    return _classify(candidates[0][1])


def extract_annotations_python_ast(
    file_path: str, source: str, is_test_file: bool
) -> List[Annotation]:
    """Extract @spec annotations from Python comments + classify owners via stdlib ast."""
    # Step 1 — collect comments via tokenize (handles strings/docstrings correctly).
    comments: list[tuple[int, str]] = []  # (line, text)
    try:
        for tok in tokenize.generate_tokens(io.StringIO(source).readline):
            if tok.type == tokenize.COMMENT:
                comments.append((tok.start[0], tok.string))
    except tokenize.TokenizeError:
        return extract_annotations_regex(file_path, source, ".py", is_test_file)

    # Step 2 — parse the file once for owner classification.
    try:
        tree = ast.parse(source, filename=file_path)
    except SyntaxError:
        tree = None

    annotations: List[Annotation] = []
    for line, comment in comments:
        if "@spec" not in comment:
            continue
        ids = _extract_ids(comment)
        if not ids:
            continue
        if tree is not None:
            owner_kind, owner_name = _find_owner_after_line(tree, line + 1)
        else:
            owner_kind, owner_name = "unknown", ""
        annotations.append(
            Annotation(
                ids=ids,
                file=file_path,
                line=line,
                owner_kind=owner_kind,
                owner_name=owner_name,
                is_test_file=is_test_file,
            )
        )
    return annotations
