#!/usr/bin/env Rscript
# ==============================================================================
# Script: run_posterior_predictive_check.R
# Purpose: Generate posterior predictive simulations from the fitted stimulus-coded
#          DDM model, create diagnostic PPC visualizations, and save output images.
# Usage: Rscript workshop_sepex/run_posterior_predictive_check.R
# ==============================================================================

suppressPackageStartupMessages({
  library(brms)
  library(cogmod)
  library(dplyr)
  library(ggplot2)
  library(qs2)
  library(here)
})

cat("=======================================================================\n")
cat("📊 Running Posterior Predictive Check (PPC) for Stimulus-Coded DDM\n")
cat("=======================================================================\n\n")

# 1. Load Model and Data -------------------------------------------------------
model_path <- here::here("models", "ddm_cogmod_stimulus_coding_model.qs")
if (!file.exists(model_path)) {
  stop("Model file not found: ", model_path)
}

cat("📦 Loading fitted model object from:", model_path, "\n")
model_ddm <- qs2::qs_read(model_path)

data_obs <- model_ddm$data
n_obs <- nrow(data_obs)
cat(sprintf("ℹ️  Model data contains %d observations across %d subjects.\n", 
            n_obs, nlevels(factor(data_obs$Participant))))

# 2. Posterior Predictive Simulations ------------------------------------------
# Set number of posterior draws (e.g. 50 draws provides stable prediction bands)
n_draws <- 50
cat(sprintf("\n⏳ Generating posterior predictive draws (ndraws = %d)...\n", n_draws))
start_time <- Sys.time()

# posterior_predict generates (RT, choice) pairs for each observation
preds <- posterior_predict(model_ddm, ndraws = n_draws)

elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)
cat(sprintf("✅ Predictions generated in %s seconds.\n\n", elapsed))

# 3. Reshape and Aggregate Simulations -----------------------------------------
cat("🔄 Wrangling empirical and simulated distributions...\n")
rts_sim <- preds[, seq(1, ncol(preds), by = 2), drop = FALSE]
choices_sim <- preds[, seq(2, ncol(preds), by = 2), drop = FALSE]

# Prepare observed summary
obs_df <- data.frame(
  rt = data_obs$rt,
  response_choice = factor(data_obs$response_choice, levels = c(0, 1), labels = c("Nonword (0)", "Word (1)")),
  stimulus_type = data_obs$stimulus_type,
  Condition = data_obs$Condition,
  Type = "Observed"
)

# Sample a subset of simulated replicates for density overlays
n_rep_plot <- min(20, n_draws)
sim_list <- vector("list", n_rep_plot)
for (s in seq_len(n_rep_plot)) {
  sim_list[[s]] <- data.frame(
    rt = rts_sim[s, ],
    response_choice = factor(choices_sim[s, ], levels = c(0, 1), labels = c("Nonword (0)", "Word (1)")),
    stimulus_type = data_obs$stimulus_type,
    Condition = data_obs$Condition,
    rep = factor(s),
    Type = "Posterior Predicted"
  )
}
sim_df <- do.call(rbind, sim_list)

# 4. Plot Posterior Predictive RT Distributions --------------------------------
cat("🎨 Creating Posterior Predictive Distribution Plot...\n")

p_ppc <- ggplot() +
  # Model predicted replicates as thin semitransparent lines
  geom_density(
    data = sim_df,
    aes(x = rt, color = response_choice, group = interaction(rep, response_choice)),
    alpha = 0.25,
    linewidth = 0.35,
    adjust = 1.2
  ) +
  # Observed empirical distribution as bold solid line
  geom_density(
    data = obs_df,
    aes(x = rt, color = response_choice),
    linewidth = 1.1,
    adjust = 1.2
  ) +
  facet_grid(Condition ~ stimulus_type, scales = "free_y") +
  scale_color_manual(
    values = c("Nonword (0)" = "#1F497D", "Word (1)" = "#C2002F"),
    labels = c("Nonword Boundary (0)", "Word Boundary (1)")
  ) +
  coord_cartesian(xlim = c(0.18, 1.8)) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 12),
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "#444444", size = 11)
  ) +
  labs(
    title = "Posterior Predictive Check: Stimulus-Coded DDM",
    subtitle = "Thick lines: Observed empirical density | Thin lines: 20 posterior predictive simulations (y_rep)",
    x = "Reaction Time (seconds)",
    y = "Density",
    color = "Response Boundary"
  )

# 5. Save Output Plot ----------------------------------------------------------
out_dir <- here::here("workshop_sepex", "images")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

out_file <- file.path(out_dir, "stimulus_ppc.png")
cat(sprintf("💾 Saving PPC figure to: %s\n", out_file))
ggsave(out_file, p_ppc, width = 11, height = 6.2, dpi = 300)

cat("\n🎉 PPC script completed successfully! You can inspect the figure in workshop_sepex/images/stimulus_ppc.png\n")
cat("=======================================================================\n")
