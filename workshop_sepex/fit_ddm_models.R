#!/usr/bin/env Rscript
# ==============================================================================
# Script: fit_ddm_models.R
# Purpose: Fit hierarchical Drift Diffusion Model (DDM) on Wagenmakers et al. (2008)
#          lexical decision data using brms and the cogmod package inside Docker.
#
# Model Specification:
#   - Response: RT | dec(Error)
#   - Drift rate (mu): Condition * Frequency + (1 | Participant) + (1 | Item)
#   - Boundary (boundary): Condition
#   - Non-decision time (ndt): Condition
#   - Bias (bias): 1
#   - Sum contrasts applied to Condition and Frequency
#
# Serialization: Saves model and summary to models/ using qs2::qs_save()
# ==============================================================================

suppressPackageStartupMessages({
  library(cogmod)
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(qs2)
  library(here)
})

cat("===============================================================\n")
cat("🚀 Starting Hierarchical Drift Diffusion Model (DDM) Fitting\n")
cat("===============================================================\n")

# 1. Environment & Parallelization ---------------------------------------------
n_cores <- parallel::detectCores()
sampling_cores <- min(4, max(1, n_cores - 1))
cat(sprintf("ℹ️  Available CPU cores: %d | Utilizing for sampling: %d\n", n_cores, sampling_cores))

# 2. Data Preparation & Contrast Coding ----------------------------------------
cat("📦 Loading and wrangling Wagenmakers et al. (2008) dataset from rtdists...\n")
data(speed_acc, package = "rtdists")

df <- data.frame(
  Participant = factor(as.character(speed_acc$id)),
  Item = droplevels(factor(as.character(speed_acc$stim))),
  Condition = factor(
    unname(c(accuracy = "Accuracy", speed = "Speed")[as.character(speed_acc$condition)]),
    levels = c("Accuracy", "Speed")
  ),
  RT = speed_acc$rt,
  Error = as.integer(as.character(speed_acc$response) != as.character(speed_acc$stim_cat)),
  Frequency = factor(
    unname(c(high = "High", low = "Low", very_low = "Very Low")[sub("^nw_", "", as.character(speed_acc$frequency))]),
    levels = c("High", "Low", "Very Low")
  )
)

# Subset to participants 1, 2, 3 and RT <= 2s (following Makowski's vignette)
df_subset <- df %>%
  filter(Participant %in% c("1", "2", "3"), RT <= 2) %>%
  droplevels()

cat(sprintf("ℹ️  Filtered dataset: %d trials across %d participants and %d unique items.\n",
            nrow(df_subset), nlevels(df_subset$Participant), nlevels(df_subset$Item)))

# Apply sum-to-zero contrasts
contrasts(df_subset$Condition) <- contr.sum(2)
colnames(contrasts(df_subset$Condition)) <- c("Acc_vs_Speed")

contrasts(df_subset$Frequency) <- contr.sum(3)
colnames(contrasts(df_subset$Frequency)) <- c("High_vs_VLow", "Low_vs_VLow")

cat("✅ Contrasts successfully set:\n")
cat("   Condition contrasts (Accuracy = 1, Speed = -1):\n")
print(contrasts(df_subset$Condition))
cat("   Frequency contrasts (Sum to zero):\n")
print(contrasts(df_subset$Frequency))

# 3. Model Formula Specification -----------------------------------------------
cat("\n📐 Setting up brms formula with cogmod_ddm() family...\n")
f_ddm <- bf(
  RT | dec(Error) ~ Condition * Frequency + (1 | Participant) + (1 | Item),
  boundary ~ Condition,
  ndt ~ Condition,
  bias = 0.5,
  sigmadrift = 0,
  sigmabias = 0,
  sigmandt = 0,
  family = cogmod_ddm()
)

# 4. Priors, Inits, and Stanvars -----------------------------------------------
cat("⚙️  Generating automatic priors, inits, and Stanvars via cogmod...\n")
prior_ddm <- cogmod_priors(f_ddm, df_subset)
init_ddm <- cogmod_inits(f_ddm, df_subset)
stanvars_ddm <- cogmod_stanvars(f_ddm)

# 5. Model Estimation with brm & cmdstanr --------------------------------------
cat("\n⏳ Launching MCMC sampling via cmdstanr (4 chains, 1000 iter, 500 warmup)...\n")
start_time <- Sys.time()

model_ddm <- brm(
  formula = f_ddm,
  data = df_subset,
  prior = prior_ddm,
  init = init_ddm,
  stanvars = stanvars_ddm,
  chains = 4,
  cores = sampling_cores,
  iter = 1000,
  warmup = 500,
  backend = "cmdstanr",
  file_refit = "always"
)

elapsed_time <- round(difftime(Sys.time(), start_time, units = "mins"), 2)
cat(sprintf("✅ Sampling completed in %s minutes!\n", elapsed_time))

# 6. Extract Summaries & Save Objects ------------------------------------------
output_dir <- here::here("models")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

model_file <- file.path(output_dir, "ddm_cogmod_model.qs")
summary_file <- file.path(output_dir, "ddm_cogmod_summary.qs")

cat(sprintf("💾 Saving full fitted model object to: %s\n", model_file))
qs2::qs_save(model_ddm, model_file)

cat("📊 Generating and saving model summary...\n")
model_summary <- list(
  fixed_effects = brms::fixef(model_ddm),
  random_effects = brms::VarCorr(model_ddm),
  formula = f_ddm,
  elapsed_mins = as.numeric(elapsed_time),
  n_obs = nrow(df_subset),
  n_participants = nlevels(df_subset$Participant),
  n_items = nlevels(df_subset$Item)
)

qs2::qs_save(model_summary, summary_file)

cat("🎉 Done! Model and summary have been successfully saved.\n")
cat("===============================================================\n")
