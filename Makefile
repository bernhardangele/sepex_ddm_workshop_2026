# Makefile for SEPEX DDM Workshop 2026 Presentation

PORT ?= 8889
QMD = workshop_sepex/drift_diffusion_modeling.qmd
HTML = workshop_sepex/drift_diffusion_modeling.html
SERVER = workshop_sepex/serve.py

.PHONY: all build presentation serve webserver preview clean help

# Default target: build the presentation
all: presentation

# Build the Reveal.js presentation HTML from QMD
presentation: $(HTML)

$(HTML): $(QMD)
	quarto render $(QMD)

build: presentation

# Start the webserver to view the presentation on port 8889
serve:
	python3 $(SERVER) $(PORT)

webserver: serve

# Optional live preview using Quarto's built-in preview server
preview:
	quarto preview $(QMD) --port $(PORT) --no-browser

# Clean generated HTML and Quarto cache
clean:
	rm -rf $(HTML) workshop_sepex/drift_diffusion_modeling_files .quarto

help:
	@echo "Available make targets:"
	@echo "  make (or make presentation / make build) - Render Reveal.js presentation HTML"
	@echo "  make serve (or make webserver)           - Start HTTP webserver on port $(PORT)"
	@echo "  make preview                             - Run Quarto live preview server"
	@echo "  make clean                               - Remove generated HTML and Quarto cache"
