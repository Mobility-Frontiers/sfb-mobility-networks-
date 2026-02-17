# synthetic_demo.R
# Full pipeline demonstration on synthetic GPS data
#
# Runs the complete SFB workflow: GPS simulation → co-presence networks →
# SFB scores → mobility models. No real GPS data required.
#
# Run from project root:
#   Rscript synthetic/synthetic_demo.R
#
# RC - 2025

library(tidyverse)
library(lubridate)

cat("==========================================================\n")
cat("  Spatial Functional Bandwidth — synthetic pipeline demo  \n")
cat("==========================================================\n\n")

if (!dir.exists("data")) dir.create("data")
if (!dir.exists("docs")) dir.create("docs")

# -------------------------------------------------------------------
# Step 0. Generate synthetic data
# -------------------------------------------------------------------

source("synthetic/simulate_gps.R")
cat("\n")

# -------------------------------------------------------------------
# Step 1. Build multiplex co-presence network
# -------------------------------------------------------------------

cat("Step 1: Building multiplex co-presence network...\n")

visits  <- read_csv("data/synthetic_visits.csv",  show_col_types = FALSE)
devices <- read_csv("data/synthetic_devices.csv", show_col_types = FALSE)

poi_types       <- c("labor", "educational", "cultural", "consumption")
time_window_min <- 30
L               <- length(poi_types)

build_copresence_layer <- function(visits, layer_type, time_window_min) {
  lv <- visits %>%
    filter(poi_type == layer_type) %>%
    select(device_id, poi_id, timestamp, home_ses)

  lv %>%
    inner_join(lv, by = "poi_id", suffix = c("_i", "_j"),
               relationship = "many-to-many") %>%
    filter(
      device_id_i != device_id_j,
      home_ses_i  == "low",
      home_ses_j  == "high",
      abs(as.numeric(difftime(timestamp_i, timestamp_j, units = "mins"))) <= time_window_min
    ) %>%
    distinct(device_id_i, device_id_j) %>%
    mutate(layer = layer_type)
}

edges_by_layer <- map_dfr(poi_types,
                           ~build_copresence_layer(visits, .x, time_window_min))

cat("  Co-presence edges per layer:\n")
edges_by_layer %>%
  count(layer) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  pwalk(function(layer, n, pct) {
    cat(sprintf("    %-15s %d edges  (%s%%)\n", layer, n, pct))
  })

# -------------------------------------------------------------------
# Step 2. Compute SFB scores
# -------------------------------------------------------------------

cat("\nStep 2: Computing SFB scores...\n")

sfb_scores <- edges_by_layer %>%
  group_by(device_id_i, device_id_j) %>%
  summarise(n_shared_layers = n_distinct(layer), .groups = "drop") %>%
  group_by(device_id_i) %>%
  summarise(
    sfb                = sum(n_shared_layers / L) / n_distinct(device_id_j),
    n_unique_neighbors = n_distinct(device_id_j),
    total_contacts     = sum(n_shared_layers),
    .groups = "drop"
  ) %>%
  rename(device_id = device_id_i) %>%
  left_join(select(devices, device_id, ses_quintile, mobility_type),
            by = "device_id")

cat(sprintf("  Devices with at least one inter-class contact: %d\n", nrow(sfb_scores)))
cat(sprintf("  Mean SFB:    %.3f  (min %.3f  max %.3f)\n",
            mean(sfb_scores$sfb),
            min(sfb_scores$sfb),
            max(sfb_scores$sfb)))
cat(sprintf("  Baseline SFB (single-layer contacts only): %.3f\n", 1/L))
cat(sprintf("  SFB range above baseline: %.3f\n",
            max(sfb_scores$sfb) - 1/L))

# SFB by mobility type — confirms the pipeline recovers the injected structure
cat("\n  Mean SFB by mobility type (should increase: constrained < partial < diverse):\n")
sfb_scores %>%
  group_by(mobility_type) %>%
  summarise(mean_sfb = round(mean(sfb), 3), n = n(), .groups = "drop") %>%
  arrange(mean_sfb) %>%
  pwalk(function(mobility_type, mean_sfb, n) {
    cat(sprintf("    %-12s  SFB = %.3f  (n=%d)\n", mobility_type, mean_sfb, n))
  })

# -------------------------------------------------------------------
# Step 3. Simulate mobility outcome and models
#
#  DGP: logistic with SFB as the main predictor
#  Rescaled to actual SFB range so the effect is recoverable
# -------------------------------------------------------------------

cat("\nStep 3: Mobility outcome models...\n")

sfb_range <- max(sfb_scores$sfb) - min(sfb_scores$sfb)
sfb_center <- mean(sfb_scores$sfb)

set.seed(99)
sfb_scores <- sfb_scores %>%
  mutate(
    # Centre and scale SFB so beta_sfb has interpretable magnitude
    sfb_scaled = (sfb - sfb_center) / sfb_range,
    log_odds   = -0.8 + 3.5 * sfb_scaled + 0.015 * log1p(total_contacts),
    p_mobile   = plogis(log_odds),
    mobile     = rbinom(n(), 1, p_mobile)
  )

cat(sprintf("  Overall mobility rate: %.1f%%\n", mean(sfb_scores$mobile) * 100))

m_nul <- glm(mobile ~ 1,                           data = sfb_scores, family = binomial)
m_vol <- glm(mobile ~ total_contacts,              data = sfb_scores, family = binomial)
m_sfb <- glm(mobile ~ sfb,                         data = sfb_scores, family = binomial)
m_ful <- glm(mobile ~ sfb + total_contacts,        data = sfb_scores, family = binomial)

pseudo_r2 <- function(m) round(1 - as.numeric(logLik(m)) / as.numeric(logLik(m_nul)), 3)

cat("\n  Model comparison (McFadden pseudo-R2):\n")
cat(sprintf("    Contact volume only : %.3f\n", pseudo_r2(m_vol)))
cat(sprintf("    SFB only            : %.3f\n", pseudo_r2(m_sfb)))
cat(sprintf("    SFB + volume        : %.3f\n", pseudo_r2(m_ful)))

cat("\n  H1: SFB coefficient in full model:\n")
broom::tidy(m_ful, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  mutate(across(where(is.numeric), ~round(.x, 4))) %>%
  select(term, estimate, std.error, p.value, conf.low, conf.high) %>%
  as.data.frame() %>%
  print(row.names = FALSE)

# -------------------------------------------------------------------
# Step 4. Threshold check (H2)
# -------------------------------------------------------------------

cat("\nStep 4: Mobility rate by SFB bin (threshold check)...\n")

mobility_by_sfb <- sfb_scores %>%
  mutate(sfb_bin = ntile(sfb, 5)) %>%
  group_by(sfb_bin) %>%
  summarise(
    sfb_mean     = round(mean(sfb), 3),
    mobility_rate = mean(mobile),
    n            = n(),
    .groups = "drop"
  )

cat("\n  Quintile  Mean SFB  Mobility rate\n")
mobility_by_sfb %>%
  mutate(bar = strrep("█", round(mobility_rate * 25))) %>%
  pwalk(function(sfb_bin, sfb_mean, mobility_rate, n, bar) {
    cat(sprintf("    Q%d       %.3f     %.2f  %s (n=%d)\n",
                sfb_bin, sfb_mean, mobility_rate, bar, n))
  })

# -------------------------------------------------------------------
# Step 5. Plots
# -------------------------------------------------------------------

cat("\nStep 5: Saving plots to docs/...\n")

p_dist <- ggplot(sfb_scores, aes(x = sfb)) +
  geom_histogram(bins = 30, fill = "#2c7bb6", color = "white", alpha = 0.85) +
  geom_vline(xintercept = 1/L, linetype = "dashed",
             color = "gray30", linewidth = 0.7) +
  annotate("text", x = 1/L + 0.005, y = Inf, vjust = 2, hjust = 0,
           label = "Single-layer\nbaseline (1/L)",
           size = 3.2, color = "gray30") +
  labs(
    title    = "Distribution of Spatial Functional Bandwidth (SFB)",
    subtitle = "Low-SES devices | synthetic data (n = 600 devices, 45 days)",
    x = "SFB score", y = "Count"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

p_grad <- mobility_by_sfb %>%
  mutate(sfb_bin = factor(paste0("Q", sfb_bin))) %>%
  ggplot(aes(x = sfb_bin, y = mobility_rate)) +
  geom_col(fill = "#d7191c", alpha = 0.82, width = 0.65) +
  geom_hline(yintercept = mean(sfb_scores$mobile),
             linetype = "dashed", color = "gray40", linewidth = 0.7) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title    = "Mobility Rate by SFB Quintile",
    subtitle = "Dashed = overall mobility rate",
    x = "SFB quintile (Q1 = lowest functional bandwidth)",
    y = "Pr(upward mobility)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

p_type <- sfb_scores %>%
  filter(!is.na(mobility_type)) %>%
  ggplot(aes(x = sfb, fill = mobility_type)) +
  geom_density(alpha = 0.55) +
  scale_fill_manual(
    values = c(constrained = "#d7191c", partial = "#fdae61", diverse = "#2c7bb6"),
    name   = "Spatial mobility\nprofile"
  ) +
  geom_vline(xintercept = 1/L, linetype = "dashed", color = "gray30") +
  labs(
    title    = "SFB Distribution by Spatial Mobility Profile",
    subtitle = "Low-SES devices only",
    x = "SFB score", y = "Density"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave("docs/sfb_distribution.png",     p_dist, width = 7, height = 4, dpi = 150)
ggsave("docs/sfb_mobility_gradient.png", p_grad, width = 7, height = 4, dpi = 150)
ggsave("docs/sfb_by_mobility_type.png", p_type, width = 7, height = 4, dpi = 150)

# -------------------------------------------------------------------
# Done
# -------------------------------------------------------------------

write_csv(sfb_scores, "data/sfb_scores.csv")

cat("\n==========================================================\n")
cat("  Pipeline complete.\n")
cat("  Outputs:\n")
cat("    data/sfb_scores.csv\n")
cat("    docs/sfb_distribution.png\n")
cat("    docs/sfb_mobility_gradient.png\n")
cat("    docs/sfb_by_mobility_type.png\n")
cat("==========================================================\n")

# TODO: Davies test for threshold detection (segmented pkg)
# TODO: Moran's I on model residuals for spatial autocorrelation check
