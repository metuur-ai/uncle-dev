"""Dispatcher — selects the right extractor for a file and returns annotations."""

import os
import re
from typing import List

from .extract_python_ast import extract_annotations_python_ast
from .extract_regex import extract_annotations_regex
from .extract_treesitter import extract_annotations_treesitter, is_available
from .types import Annotation


# Path patterns that classify a file as a test.
_TEST_PATH_PATTERNS = [
    re.compile(r"\.test\.[a-z]+$"),
    re.compile(r"\.spec\.[a-z]+$"),
    re.compile(r"_test\.[a-z]+$"),
    re.compile(r"^test_.+\.py$"),
    re.compile(r"(^|/)tests?/"),
    re.compile(r"(^|/)__tests__/"),
]


def is_test_path(path: str) -> bool:
    norm = path.replace("\\", "/")
    base = os.path.basename(norm)
    for pat in _TEST_PATH_PATTERNS:
        if pat.search(norm) or pat.search(base):
            return True
    return False


def extract_annotations(
    file_path: str, source: str, *, force_regex: bool = False
) -> List[Annotation]:
    """Extract @spec annotations from one file.

    Selection order:
      1. tree-sitter (if available and not force_regex)
      2. stdlib `ast` for .py files
      3. comment-aware regex fallback
    """
    ext = os.path.splitext(file_path)[1].lower()
    is_test = is_test_path(file_path)

    if not force_regex and is_available():
        ts_result = extract_annotations_treesitter(file_path, source, ext, is_test)
        if ts_result is not None:
            return ts_result

    if ext == ".py":
        return extract_annotations_python_ast(file_path, source, is_test)

    return extract_annotations_regex(file_path, source, ext, is_test)
