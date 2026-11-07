# Configuration file for the Sphinx documentation builder.
#
# Build with:  sphinx-build -b html . _build/html

project = "sctb"
author = "Filippo Savi"
copyright = "2026, University of Nottingham"

extensions = []

primary_domain = "cpp"
highlight_language = "cpp"
templates_path = []
exclude_patterns = ["_build"]

html_theme = "sphinx_rtd_theme"
html_title = "sctb, SystemC testbenches for Verilator"
