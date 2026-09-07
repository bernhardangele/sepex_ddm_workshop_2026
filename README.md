# SEPEX DDM Workshop 2026: Drift Diffusion Modeling in R with `brms` and `cogmod`

**Author:** Dr. Bernhard Angele  
**Event:** SEPEX DDM Workshop 2026  
**Presentation:** [https://bernhardangele.github.io/sepex_ddm_workshop_2026/](https://bernhardangele.github.io/sepex_ddm_workshop_2026/)  
**GitHub Repository:** [https://github.com/bernhardangele/sepex_ddm_workshop_2026](https://github.com/bernhardangele/sepex_ddm_workshop_2026)

---

## Overview

This repository contains materials for an introductory workshop on fitting hierarchical **Drift Diffusion Models (DDM)** using Bayesian regression in R.

Fitting diffusion models within a generalized linear mixed-modeling framework has historically been challenging. This workshop demonstrates how to combine **`brms`**, **Stan** (via `cmdstanr`), and the **`cogmod`** package to specify, fit, and evaluate full Bayesian hierarchical DDMs with crossed random effects for participants and items.

### Key Modeling Topics Covered

- **Stimulus-coding vs. Accuracy-coding:** Why mapping responses to categorical boundaries ($0 = \text{Nonword}$, $1 = \text{Word}$) resolves the data-sparsity problem of lexical decision error boundaries.
- **Orthogonal Contrast Coding:** Applying planned Helmert contrasts to map drift rates ($\mu$) directly to lexical status (Word vs. Nonword) and word frequency (High vs. Low), alongside sum contrasts for speed vs. accuracy instructions.
- **Appropriate Link Functions:** Using `softplus` for boundary separation ($a$) to avoid numerical explosions, `log` for non-decision time ($t_0$), `logit` for starting point bias ($z$), and `identity` for drift rate ($\mu$).
- **Crossed Random Effects:** Simultaneously accounting for individual differences across participants (`(1 | id)`) and item difficulty across stimuli (`(1 | item)`).
- **Posterior Predictive Checks (PPC):** Validating the fit against empirical RT distributions across experimental conditions.

---

## Repository Structure

```text
sepex_ddm_workshop_2026/
├── .devcontainer/
│   └── devcontainer.json               # VS Code Dev Container definition
├── .github/
│   └── workflows/
│       └── deploy-pages.yml            # Automated GitHub Pages deployment
├── Makefile                            # Orchestrates build, preview, and server commands
├── AGENTS.md                           # Guidelines and conventions for AI assistants
├── README.md                           # Repository documentation and setup instructions
├── models/                             # Pre-fitted models and summary objects (qs2 format)
│   ├── ddm_cogmod_stimulus_coding_model.qs     # Full stimulus-coded hierarchical DDM
│   ├── ddm_cogmod_stimulus_coding_summary.qs   # Pre-extracted summary list for fast rendering
│   ├── ddm_cogmod_model.qs                     # Accuracy-coded model
│   └── ddm_cogmod_summary.qs                   # Accuracy-coded summary list
└── workshop_sepex/                     # Presentation source, scripts, and slide assets
    ├── drift_diffusion_modeling.qmd    # Main Quarto Reveal.js presentation
    ├── drift_diffusion_modeling.html   # Rendered Reveal.js slide deck
    ├── fit_ddm_stimulus_coding.R       # Production stimulus-coded DDM fitting script
    ├── fit_ddm_models.R                # Accuracy-coded DDM fitting script
    ├── run_posterior_predictive_check.R# Posterior predictive simulation & PPC plots
    ├── serve.py                        # Python HTTP server for presentation on port 8889
    ├── custom.scss                     # Presentation theme styles
    ├── animation_styles.css            # Custom CSS animations
    ├── references.bib                  # Workshop bibliography
    ├── apa.csl                         # APA citation style format
    └── images/                         # Plots, QR codes, and slide diagrams
```

---

## Running in the Devcontainer

Bayesian modeling with `brms` and Stan requires a C++ toolchain, `cmdstan`, specific R package versions, and system libraries (e.g., GSL). To guarantee full reproducibility across Linux, macOS, and Windows without manual configuration, this project includes a pre-configured **VS Code Dev Container**.

### Prerequisites

1. **Docker Desktop** (or Docker Engine on Linux): Ensure Docker is running.
2. **Visual Studio Code**: [Download VS Code](https://code.visualstudio.com/).
3. **Dev Containers extension**: Install the `ms-vscode-remote.remote-containers` extension from the VS Code Marketplace.

### Step-by-Step Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/bernhardangele/sepex_ddm_workshop_2026.git
   cd sepex_ddm_workshop_2026
   ```

2. **Open in VS Code:**
   ```bash
   code .
   ```

3. **Reopen in Container:**
   - When VS Code opens, a notification in the bottom right corner will appear: *"Folder contains a Dev Container configuration file. Reopen folder to in a container?"*
   - Click **Reopen in Container**.
   - Alternatively, open the Command Palette (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS), type `Dev Containers: Reopen in Container`, and press Enter.

4. **Container Setup:**
   VS Code will pull the pre-built Docker image (`bangele1/analysis-in-a-box-rocker:latest`), mount the repository, configure file permissions, and start background services automatically.

### Included Services & Port Forwarding

The devcontainer forwards two ports to your local host:

| Port | Service | Access URL | Notes |
| :--- | :--- | :--- | :--- |
| **8787** | **RStudio Server** | `http://localhost:8787` | **Username:** `rstudio`<br>**Password:** `mypassword`<br>Contains a `project/` symlink pointing directly to `/workspaces/sepex_ddm_workshop_2026`. |
| **8889** | **Presentation Server** | `http://localhost:8889` | Served when running `make serve` inside the container terminal. |

---

## Building and Viewing the Presentation

Inside the devcontainer terminal (or VS Code integrated terminal), use the provided `Makefile` targets:

### Render the Reveal.js Presentation
```bash
make presentation
# or: quarto render workshop_sepex/drift_diffusion_modeling.qmd
```
The slides will render to `workshop_sepex/drift_diffusion_modeling.html` in just a few seconds using pre-computed model summaries.

### Serve the Presentation Locally
```bash
make serve
# or: python3 workshop_sepex/serve.py 8889
```
Open `http://localhost:8889` in your web browser to navigate the interactive Reveal.js slides.

### Live Preview with Quarto
```bash
make preview
```
Runs Quarto live preview server with automatic re-rendering upon saving edits.

### Clean Generated Artifacts
```bash
make clean
```
Removes generated HTML and `.quarto/` cache files.

---

## Package Management with `pak`

This project pins CRAN packages to a reproducible snapshot date (**2026-06-24**). Always install packages using **`pak`** rather than base `install.packages()`, as `pak` automatically resolves and installs both R dependencies and required system packages (such as `libgsl0-dev`):

```r
# Install CRAN packages
pak::pkg_install("rtdists")

# Install GitHub packages
pak::pkg_install("DominiqueMakowski/cogmod")
```

---

## Model Fitting and Serialization

Pre-fitted model objects and extracted summaries are already cached in `models/` using **`qs2`** (`.qs` files) for high-speed serialization:

- To fit the primary stimulus-coded hierarchical DDM from scratch:
  ```bash
  Rscript workshop_sepex/fit_ddm_stimulus_coding.R
  ```
  *(Note: Fitting the full hierarchical model across 31,000+ observations and crossed item/participant intercepts takes ~2.6 hours on 8 CPU cores with `threads = threading(2)`).*

- To run posterior predictive checks and regenerate the PPC figure:
  ```bash
  Rscript workshop_sepex/run_posterior_predictive_check.R
  ```

---

## References

- Heathcote, A., & Love, J. (2012). Linear deterministic accumulator models of simple choice. *Frontiers in Psychology*, 3, 292.
- Makowski, D. (2025). *cogmod: Cognitive Modeling in brms*. R package version 0.3.1. [https://github.com/DominiqueMakowski/cogmod](https://github.com/DominiqueMakowski/cogmod)
- Singmann, H. (2017). Wiener: An R package for the Wiener diffusion model. *Journal of Statistical Software*.
- Wagenmakers, E.-J., Ratcliff, R., Gomez, P., & McKoon, G. (2008). A diffusion model analysis of criterion shifts in lexical decision. *Journal of Memory and Language*, 58(1), 133–159.
