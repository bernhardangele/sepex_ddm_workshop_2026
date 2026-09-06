# AI Agent Guidelines (AGENTS.md)

Welcome! This repository contains a Quarto Reveal.js presentation and supporting R scripts for an introductory workshop on fitting Drift Diffusion Models (DDM) with `brms` and `cogmod` in R (prepared for the SEPEX DDM workshop 2026 by Dr. Bernhard Angele).

As an AI coding assistant (e.g., Antigravity, Cursor, Copilot), you must strictly adhere to the project workflow, environment specifications, and coding conventions defined below to maintain reproducibility and clean organization.

---

## 1. Project Context & Architecture

This project is built on R, Quarto, Bayesian cognitive modeling (`brms` & `cogmod`), and it runs inside a dedicated Docker container environment.

*   **Environment:** Powered by the customized Docker container based on `rocker/tidyverse:4.6.1` with `verse` installation (available on Docker Hub as `bangele1/analysis-in-a-box-rocker`).
*   **Networking & Ports:**
    *   Port **8787**: RStudio Server.
    *   Port **8889**: Presentation HTTP webserver (served by [`workshop_sepex/serve.py`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/serve.py)).
*   **Reproducibility:** Uses a fixed CRAN snapshot (**2026-06-24**) to guarantee package version stability.
*   **Key Dependencies:**
    *   **Languages:** R (≥ 4.4), Quarto (`.qmd`), Python 3 (web server).
    *   **Modeling:** `brms` (Bayesian Regression Models using Stan), `cogmod` (custom DDM likelihood, link functions, and Stan code injection), `cmdstanr` (v0.9.0) with `cmdstan` (v2.39.0) located at `/opt/cmdstan/cmdstan-2.39.0`.
    *   **Data:** `rtdists` (provides lexical decision dataset `speed_acc` from Wagenmakers et al., 2008).
    *   **Serialization:** `qs2` (fast object serialization, saving/loading `.qs` files).
*   **Directory Structure:**
    *   **Root Directory (`/workspaces/sepex_ddm_workshop_2026/`):**
        *   [`Makefile`](file:///workspaces/sepex_ddm_workshop_2026/Makefile): Orchestrates building the presentation, starting the webserver, and project cleanup.
        *   [`AGENTS.md`](file:///workspaces/sepex_ddm_workshop_2026/AGENTS.md): Project rules and guidelines for AI agents.
        *   [`.devcontainer/`](file:///workspaces/sepex_ddm_workshop_2026/.devcontainer): Development container configuration forwarding ports 8787 and 8889.
    *   [`models/`](file:///workspaces/sepex_ddm_workshop_2026/models): Dedicated to storing pre-fitted serialized model objects and summaries:
        *   [`models/ddm_cogmod_stimulus_coding_model.qs`](file:///workspaces/sepex_ddm_workshop_2026/models/ddm_cogmod_stimulus_coding_model.qs): Full hierarchical stimulus-coded DDM model (17 participants, ~31,000 observations, crossed item/participant random effects).
        *   [`models/ddm_cogmod_stimulus_coding_summary.qs`](file:///workspaces/sepex_ddm_workshop_2026/models/ddm_cogmod_stimulus_coding_summary.qs): Pre-extracted summary list (fixed effects, random effects, diagnostics) used by the presentation for instant rendering.
        *   [`models/ddm_cogmod_model.qs`](file:///workspaces/sepex_ddm_workshop_2026/models/ddm_cogmod_model.qs): Alternative accuracy/error-coded model.
        *   [`models/ddm_cogmod_summary.qs`](file:///workspaces/sepex_ddm_workshop_2026/models/ddm_cogmod_summary.qs): Summary for the accuracy/error-coded model.
    *   [`workshop_sepex/`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex): Presentation source, modeling scripts, and assets:
        *   [`workshop_sepex/drift_diffusion_modeling.qmd`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/drift_diffusion_modeling.qmd): Main Quarto Reveal.js presentation document.
        *   [`workshop_sepex/drift_diffusion_modeling.html`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/drift_diffusion_modeling.html): Rendered Reveal.js slide deck.
        *   [`workshop_sepex/fit_ddm_stimulus_coding.R`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/fit_ddm_stimulus_coding.R): Standalone script specifying and fitting the production stimulus-coded DDM model.
        *   [`workshop_sepex/fit_ddm_models.R`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/fit_ddm_models.R): Script specifying and fitting the accuracy/error-coded DDM model.
        *   [`workshop_sepex/serve.py`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/serve.py): Python HTTP server serving the presentation on port 8889.
        *   [`workshop_sepex/custom.scss`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/custom.scss) & [`workshop_sepex/animation_styles.css`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/animation_styles.css): Custom slide styling.
        *   [`workshop_sepex/references.bib`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/references.bib) & [`workshop_sepex/apa.csl`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/apa.csl): Bibliography and citation style.
        *   [`workshop_sepex/images/`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/images): Posterior parameter density plots, diagnostic visualizations, and slide diagrams.

---

## 2. Core Agent Instructions & Rules

To maximize performance, reproducibility, and structural integrity, follow these rules:

### 2.1 Separation of Concerns
*   **No Heavy Computations in Quarto:** Bayesian model fitting takes significant compute time (e.g., ~2.6 hours for the full stimulus-coded DDM). Never fit models inside the Quarto presentation (`.qmd`).
*   **Lightweight Rendering:** The presentation ([`workshop_sepex/drift_diffusion_modeling.qmd`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/drift_diffusion_modeling.qmd)) must only load pre-computed summary objects using `qs2::qs_read(here::here("models", "ddm_cogmod_stimulus_coding_summary.qs"))` to guarantee fast compilation (< 5 seconds).
*   **Standalone Modeling Scripts:** Any model fitting must remain in standalone R scripts ([`workshop_sepex/fit_ddm_stimulus_coding.R`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/fit_ddm_stimulus_coding.R) or [`workshop_sepex/fit_ddm_models.R`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex/fit_ddm_models.R)). Models are already fitted and cached in [`models/`](file:///workspaces/sepex_ddm_workshop_2026/models).

### 2.2 Serialization Protocol (`qs2`)
> [!IMPORTANT]
> Always use `qs2` for serialization (`qs2::qs_save()` and `qs2::qs_read()`). Do **NOT** use the legacy `qs` package.
> Serialized files use the `.qs` extension and reside in the [`models/`](file:///workspaces/sepex_ddm_workshop_2026/models) directory.

### 2.3 Environment & Dependencies
*   **Docker Container:** Assume all commands, R scripts, and servers run inside the Docker container.
*   **Package Management:** If an R package needs to be added, install it via `pak::pkg_install("<package>")` to adhere to the pinned CRAN snapshot. Do not use plain `install.packages()`.

### 2.4 Bayesian Modeling (`brms` & `cogmod`)
*   **Backend:** Uses `cmdstanr` (v0.9.0) with Stan v2.39.0 located at `/opt/cmdstan/cmdstan-2.39.0`.
*   **Model Focus:** The primary model analyzed in this workshop is the **stimulus-coded model** (`fit_ddm_stimulus_coding.R`), which maps nonwords to the lower boundary (0) and words to the upper boundary (1), applying orthogonal Helmert contrasts for stimulus types and sum contrasts for instruction conditions.
*   **Pre-Fitted Models:** Models are already fitted and saved in [`models/`](file:///workspaces/sepex_ddm_workshop_2026/models). Do not refit them unless explicitly instructed by the user.

### 2.5 File Paths & Working Directories
*   **Root Resolution:** Use `here::here()` for resolving paths relative to the project root across R scripts and `.qmd` files (e.g. `here::here("models", "ddm_cogmod_stimulus_coding_summary.qs")`).
*   **Quarto Working Directory:** Quarto temporarily switches the working directory to [`workshop_sepex/`](file:///workspaces/sepex_ddm_workshop_2026/workshop_sepex) during rendering of `drift_diffusion_modeling.qmd`. Local assets (such as `images/`, `references.bib`, `apa.csl`, `custom.scss`) are resolved relative to `workshop_sepex/`.

### 2.6 Building and Serving Presentation
*   **Build Presentation:** Render the Reveal.js presentation with `quarto render workshop_sepex/drift_diffusion_modeling.qmd` or `make presentation`.
*   **Serve Presentation:** Start the local web server with `python3 workshop_sepex/serve.py 8889` or `make serve`. The slides will be accessible on `http://localhost:8889/`.

### 2.7 Makefile Automation
The project root [`Makefile`](file:///workspaces/sepex_ddm_workshop_2026/Makefile) provides standard targets:
*   `make` or `make presentation`: Renders the Quarto Reveal.js presentation to HTML.
*   `make serve` or `make webserver`: Starts the Python HTTP server on port 8889.
*   `make clean`: Removes generated HTML and Quarto cache artifacts.

### 2.8 GitHub Pages Deployment
A GitHub Actions workflow ([`.github/workflows/deploy-pages.yml`](file:///workspaces/sepex_ddm_workshop_2026/.github/workflows/deploy-pages.yml)) automatically publishes the presentation to GitHub Pages on every push to `main`.
*   **Repository Setting:** In GitHub repo Settings > Pages, ensure "Source" is set to **GitHub Actions**.
*   **Root URL Access:** The workflow copies the rendered presentation to `index.html` in the deployed site so the slides are served immediately at the root URL.
