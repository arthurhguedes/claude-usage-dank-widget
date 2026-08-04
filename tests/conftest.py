import importlib.machinery
import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "bin" / "claude-usage-json"


@pytest.fixture
def mod():
    """Carrega bin/claude-usage-json como modulo Python fresco a cada teste.

    O arquivo nao tem extensao .py (e um executavel instalado em PATH), entao
    spec_from_file_location nao consegue inferir o loader sozinho -- precisa
    de um SourceFileLoader explicito.
    """
    loader = importlib.machinery.SourceFileLoader("claude_usage_json", str(SCRIPT_PATH))
    spec = importlib.util.spec_from_file_location("claude_usage_json", SCRIPT_PATH, loader=loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module
