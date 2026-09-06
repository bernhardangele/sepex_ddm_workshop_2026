#!/usr/bin/env Rscript
# ==============================================================================
# Script: fit_ddm_stimulus_coding.R
# Purpose: Fit hierarchical Drift Diffusion Model (DDM) on Wagenmakers et al. (2008)
#          lexical decision data using stimulus coding (choice: nonword vs. word)
#          with censored data, Helmert contrasts, and sum contrasts inside Docker.
#
# Design & Predictor Specifications:
#   1. Censoring: Filter out trials flagged by `censor` in rtdists::speed_acc
#      (eliminates fast <180ms, slow >3s, and uninterpretable error presses).
#   2. Choice Outcome:
#      - nonword = 0 (lower boundary)
#      - word    = 1 (upper boundary)
#   3. Predictor 1: stimulus_type (3 levels)
#      - "nonword"
#      - "low"  (collapsing "low frequency" and "very low frequency" words)
#      - "high" ("high frequency" words)
#      - Contrasts (Helmert):
#        * Comparison 1: Nonword vs. Word (average of high and low)
#        * Comparison 2: Low vs. High frequency words
#   4. Predictor 2: Condition (sum-coded, Accuracy = +1, Speed = -1)
#   5. Interaction: stimulus_type * Condition on drift rate (mu)
#   6. Random Effects: Crossed random intercepts for Participants and Items
#   7. Sampler Tuning: adapt_delta = 0.95 to eliminate divergent transitions
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

cat("=======================================================================\n")
cat("🚀 Fitting Stimulus-Coded Hierarchical Drift Diffusion Model (DDM)\n")
cat("=======================================================================\n\n")

# 1. Hardware & CPU Cores ------------------------------------------------------
n_cores <- parallel::detectCores()
sampling_cores <- min(4, max(1, n_cores - 1))
cat(sprintf("ℹ️  Available CPU cores: %d | Utilizing for sampling: %d\n\n", n_cores, sampling_cores))

# 2. Load & Preprocess Censored Data -------------------------------------------
cat("📦 Loading Wagenmakers et al. (2008) dataset from rtdists...\n")
data(speed_acc, package = "rtdists")

cat("🧹 Applying censoring filter (!censor) to eliminate outliers & uninterpretable presses...\n")
data_clean <- speed_acc[!speed_acc$censor, ]

# Include all subjects
df <- data_clean %>%
  droplevels()

cat(sprintf("🎯 Including all %d participants in analysis\n", nlevels(factor(df$id))))

# 3. Construct Model Variables -------------------------------------------------
# Response choice: nonword = 0 (lower boundary), word = 1 (upper boundary)
df$response_choice <- ifelse(df$response == "word", 1L, 0L)

# Identifiers
df$Participant <- factor(df$id)
df$Item <- factor(df$stim)

# Condition: Speed vs. Accuracy (Sum-coded)
df$Condition <- factor(df$condition, levels = c("accuracy", "speed"))
contrasts(df$Condition) <- contr.sum(2)
colnames(contrasts(df$Condition)) <- c("Acc_vs_Speed")

# Stimulus Type: nonword vs. low vs. high
df$stimulus_type <- with(df, ifelse(stim_cat == "nonword", "nonword",
                             ifelse(frequency %in% c("low", "very_low"), "low",
                             ifelse(frequency == "high", "high", NA))))
df$stimulus_type <- factor(df$stimulus_type, levels = c("high", "low", "nonword"))

# Helmert Contrasts:
# Comparison 1: Nonword vs. Word (Nonword = 2, High = -1, Low = -1)
# Comparison 2: Low vs. High frequency (Low = 1, High = -1, Nonword = 0)
helmert_mat <- contr.helmert(3)[, c(2, 1)]
colnames(helmert_mat) <- c("Nonword_vs_Word", "Low_vs_High")
contrasts(df$stimulus_type) <- helmert_mat

cat("\n📊 Data Summary:\n")
cat(sprintf("   Total valid trials: %d\n", nrow(df)))
cat(sprintf("   Unique participants: %d | Unique items: %d\n", nlevels(df$Participant), nlevels(df$Item)))
cat("   Choice distribution (0 = Nonword, 1 = Word):\n")
print(table(df$response_choice, dnn = "Choice"))
cat("   Stimulus Type distribution:\n")
print(table(df$stimulus_type, dnn = "Stimulus Type"))

cat("\n📐 Contrast Matrices:\n")
cat("   Condition (Sum Contrast):\n")
print(contrasts(df$Condition))
cat("   Stimulus Type (Helmert Contrasts):\n")
print(contrasts(df$stimulus_type))

# 4. Model Formula Specification -----------------------------------------------
cat("\n📐 Setting up brms formula with cogmod_ddm() family...\n")
f_ddm <- bf(
  # Drift Rate (mu): stimulus_type * Condition interaction + crossed random intercepts
  rt | dec(response_choice) ~ stimulus_type * Condition + (1 | Participant) + (1 | Item),
  
  # Boundary Separation: manipulated by speed vs. accuracy instructions
  boundary ~ Condition,
  
  # Non-Decision Time: estimated across speed/accuracy conditions
  ndt ~ Condition,
  
  # Starting Point Bias: relative distance from lower boundary (0 = nonword)
  bias ~ 1,
  
  # Pure Wiener process parameters fixed to 0
  sigmadrift = 0,
  sigmabias = 0,
  sigmandt = 0,
  family = cogmod_ddm()
)

# 5. Automatic Priors, Inits, and Stanvars --------------------------------------
cat("⚙️  Generating automatic priors, inits, and Stanvars via cogmod...\n")
prior_ddm <- cogmod_priors(f_ddm, df)
init_ddm  <- cogmod_inits(f_ddm, df)
sv_ddm    <- cogmod_stanvars(f_ddm)

# 6. MCMC Sampling via cmdstanr ------------------------------------------------
cat("\n⏳ Launching MCMC sampling via cmdstanr...\n")
cat("   4 chains | 1000 iter (500 warmup) | adapt_delta = 0.95 | max_treedepth = 12\n\n")
start_time <- Sys.time()

model_ddm <- brm(
  formula  = f_ddm,
  data     = df,
  prior    = prior_ddm,
  init     = init_ddm,
  stanvars = sv_ddm,
  chains   = 4,
  cores    = sampling_cores,
  threads  = threading(2),
  iter     = 1000,
  warmup   = 500,
  backend  = "cmdstanr",
  control  = list(adapt_delta = 0.95, max_treedepth = 12),
  file_refit = "always"
)

elapsed_time <- round(difftime(Sys.time(), start_time, units = "mins"), 2)
cat(sprintf("\n✅ Sampling completed successfully in %s minutes!\n", elapsed_time))

# 7. Serialize Output with qs2 -------------------------------------------------
output_dir <- here::here("models")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

model_file <- file.path(output_dir, "ddm_cogmod_stimulus_coding_model.qs")
summary_file <- file.path(output_dir, "ddm_cogmod_stimulus_coding_summary.qs")

cat(sprintf("💾 Saving full fitted model object to: %s\n", model_file))
qs2::qs_save(model_ddm, model_file)

cat("📊 Generating and saving model summary...\n")
model_summary <- list(
  fixed_effects  = brms::fixef(model_ddm),
  random_effects = brms::VarCorr(model_ddm),
  formula        = f_ddm,
  elapsed_mins   = as.numeric(elapsed_time),
  n_obs          = nrow(df),
  n_participants = nlevels(df$Participant),
  n_items        = nlevels(df$Item),
  contrasts_stim = contrasts(df$stimulus_type),
  contrasts_cond = contrasts(df$Condition)
)

qs2::qs_save(model_summary, summary_file)

cat("\n🎉 Finished! Model and summary successfully saved.\n")
cat("=======================================================================\n")
