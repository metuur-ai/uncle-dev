"""Tree-sitter based extraction with per-language owner classification.

Loads grammars from `tree_sitter_languages` (or `tree_sitter_language_pack` as
fallback). Walks comment nodes, finds the next named sibling, and classifies it
into owner_kind.

Returns None for the whole module if tree-sitter is unavailable or the language
grammar is missing — callers fall back to regex/ast.
"""

from typing import List, Optional

from .extract_regex import _extract_ids
from .types import Annotation


# Lazy-loaded language modules. None = not yet attempted, False = unavailable.
_GET_PARSER = None
_GET_LANGUAGE = None


def _try_import_treesitter():
    """Attempt to import tree-sitter and a grammar pack. Cache the result."""
    global _GET_PARSER, _GET_LANGUAGE
    if _GET_PARSER is False:
        return False
    if _GET_PARSER is not None:
        return True
    try:
        from tree_sitter_languages import get_language, get_parser  # type: ignore

        _GET_LANGUAGE = get_language
        _GET_PARSER = get_parser
        return True
    except ImportError:
        pass
    try:
        from tree_sitter_language_pack import get_language, get_parser  # type: ignore

        _GET_LANGUAGE = get_language
        _GET_PARSER = get_parser
        return True
    except ImportError:
        _GET_PARSER = False
        _GET_LANGUAGE = False
        return False


def is_available() -> bool:
    return _try_import_treesitter()


# Tree-sitter language name per file extension.
EXT_TO_TS_LANG = {
    ".ts": "typescript",
    ".tsx": "tsx",
    ".js": "javascript",
    ".jsx": "javascript",
    ".mjs": "javascript",
    ".cjs": "javascript",
    ".py": "python",
    ".go": "go",
    ".rs": "rust",
    ".java": "java",
    ".html": "html",
    ".htm": "html",
}


# Comment node type names per language family.
COMMENT_NODE_TYPES = {
    "typescript", "tsx", "javascript",
    "python", "go", "rust", "java", "html",
}


def _is_comment_node(node, lang: str) -> bool:
    t = node.type
    return t in {"comment", "line_comment", "block_comment", "doc_comment"}


def _classify_owner(node, lang: str) -> tuple[str, str]:
    """Classify an AST node into (owner_kind, owner_name).

    Pragmatic — covers the common entry-point shapes per language. Falls back
    to ('none', '') for anything we don't recognize.
    """
    if node is None:
        return "none", ""
    t = node.type

    # Walk past decorators and export markers to reach the underlying entity.
    if t in {"decorator", "decorated_definition", "export_statement"}:
        for child in node.named_children:
            if child.type not in {"decorator", "export_statement"}:
                return _classify_owner(child, lang)
        return "none", ""

    name = _identifier_of(node, lang)

    if t in {"function_declaration", "function_definition", "function_item"}:
        if name and name.startswith("test_"):
            return "test", name
        return "function", name or ""
    if t in {"method_definition", "method_declaration"}:
        return "method", name or ""
    if t in {"class_declaration", "class_definition"}:
        return "class", name or ""
    if t == "lexical_declaration":
        # const foo = () => {...} — treat as function if RHS is arrow/function
        for child in node.named_children:
            if child.type == "variable_declarator":
                for sub in child.named_children:
                    if sub.type in {"arrow_function", "function_expression", "function"}:
                        nm = _identifier_of(child, lang)
                        return "function", nm or ""
        return "none", ""
    if t == "expression_statement":
        # Top-level call like `it("...", () => ...)` or `app.get(...)`
        for child in node.named_children:
            if child.type == "call_expression":
                callee = _callee_text(child)
                if callee in {"it", "test", "describe", "fit", "xit", "specify"}:
                    return "test", _first_string_arg(child) or ""
                if any(callee.endswith(suffix) for suffix in {".get", ".post", ".put", ".delete", ".patch", ".route", ".use"}):
                    return "route", callee
        return "none", ""
    if t == "call_expression":
        callee = _callee_text(node)
        if callee in {"it", "test", "describe", "fit", "xit", "specify"}:
            return "test", _first_string_arg(node) or ""
        if any(callee.endswith(suffix) for suffix in {".get", ".post", ".put", ".delete", ".patch", ".route", ".use"}):
            return "route", callee

    return "none", ""


def _identifier_of(node, lang: str) -> Optional[str]:
    """Best-effort identifier extraction from a declaration node."""
    for child in node.named_children:
        if child.type in {"identifier", "type_identifier", "property_identifier", "field_identifier", "name"}:
            return child.text.decode("utf-8", errors="replace")
    # variable_declarator may have first child as the name
    if node.type == "variable_declarator" and node.named_child_count > 0:
        first = node.named_child(0)
        if first.type in {"identifier", "type_identifier"}:
            return first.text.decode("utf-8", errors="replace")
    return None


def _callee_text(call_node) -> str:
    """Return dotted callee name for a call_expression."""
    for child in call_node.named_children:
        if child.type in {"identifier", "member_expression", "field_expression", "selector_expression"}:
            return child.text.decode("utf-8", errors="replace")
    return ""


def _first_string_arg(call_node) -> Optional[str]:
    """Return the first string-literal argument's content, if any."""
    for child in call_node.named_children:
        if child.type == "arguments":
            for arg in child.named_children:
                if arg.type in {"string", "string_literal", "template_string"}:
                    text = arg.text.decode("utf-8", errors="replace")
                    return text.strip("\"'`")
    return None


def _next_significant_sibling(node):
    """Return the next named sibling, skipping decorators/comments/whitespace."""
    n = node.next_named_sibling
    while n is not None and n.type in {"comment", "line_comment", "block_comment", "doc_comment"}:
        n = n.next_named_sibling
    return n


def extract_annotations_treesitter(
    file_path: str, source: str, ext: str, is_test_file: bool
) -> Optional[List[Annotation]]:
    """Extract annotations using tree-sitter. Returns None if unavailable."""
    if not _try_import_treesitter():
        return None
    lang_name = EXT_TO_TS_LANG.get(ext.lower())
    if lang_name is None:
        return None
    try:
        parser = _GET_PARSER(lang_name)
    except Exception:
        return None

    try:
        tree = parser.parse(source.encode("utf-8"))
    except Exception:
        return None

    annotations: List[Annotation] = []
    cursor = tree.walk()

    def walk(node):
        if _is_comment_node(node, lang_name):
            text = node.text.decode("utf-8", errors="replace")
            if "@spec" in text:
                ids = _extract_ids(text)
                if ids:
                    sibling = _next_significant_sibling(node)
                    if sibling is None and node.parent is not None:
                        sibling = _next_significant_sibling(node.parent)
                    owner_kind, owner_name = _classify_owner(sibling, lang_name)
                    annotations.append(
                        Annotation(
                            ids=ids,
                            file=file_path,
                            line=node.start_point[0] + 1,
                            owner_kind=owner_kind,
                            owner_name=owner_name,
                            is_test_file=is_test_file,
                        )
                    )
        for child in node.named_children:
            walk(child)

    walk(tree.root_node)
    return annotations
