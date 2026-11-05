"""Sphinx configuration for the hyperpowers documentation site."""

import json
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REPO_URL = "https://github.com/scott-arne/hyperpowers"

project = "Hyperpowers"
author = "Jesse Vincent and Prime Radiant (Superpowers); Scott Johnson (Hyperpowers fork)"
copyright = "2025-2026, Jesse Vincent (Superpowers) and Scott Johnson (Hyperpowers fork)"

# vrzn keeps package.json in step with the plugin manifests, so it is the
# one place the version is read from.
release = json.loads((REPO_ROOT / "package.json").read_text())["version"]
version = release

# Read the Docs sets the branch or tag being built. Links to repository
# files follow it, so a page built from a tag shows the code it documents.
SOURCE_REF = os.environ.get("READTHEDOCS_GIT_IDENTIFIER", "main")

extensions = [
    "myst_parser",
    "sphinx_design",
    "sphinx_copybutton",
    "sphinxcontrib.mermaid",
    "sphinx.ext.extlinks",
    "sphinx_sitemap",
]
myst_enable_extensions = ["colon_fence"]
extlinks = {"source": (f"{REPO_URL}/blob/{SOURCE_REF}/%s", "%s")}
exclude_patterns = ["_build"]

html_theme = "lumina"
html_title = "Hyperpowers"
html_theme_options = {
    "source_repository": REPO_URL,
    "source_branch": SOURCE_REF,
    "source_directory": "docs/site/",
    "nav_links": [
        {"title": "GitHub", "url": REPO_URL, "external": True},
        {
            "title": "Superpowers (upstream)",
            "url": "https://github.com/obra/superpowers",
            "external": True,
        },
    ],
}

# sphinx-sitemap needs a base URL. Read the Docs provides the real one; a
# local build gets a placeholder so it does not warn, and its sitemap is
# never published.
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "http://localhost:8000/")
