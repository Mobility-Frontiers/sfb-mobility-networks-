# sfb_score.R
# Spatial Functional Bandwidth (SFB) computation from co-presence networks
#
# Steps:
#   1. Build multiplex co-presence network (one layer per POI institutional type)
#   2. Filter inter-class dyads (low SES device, high SES neighbor)
#   3. Compute SFB score per device
#   4. Estimate mobility outcome model with threshold detection
#
# Requires: synthetic_visits.csv, synthetic_pois.csv, synthetic_devices.csv
#           (from simulate_gps.R) or real GPS data with equivalent structure
#
# RC - 2025

library(tidyverse)
library(igraph)

# -------------------------------------------------------------------
# 0. Load data
# -------------------------------------------------------------------

visits  <- read_csv("data/synthetic_visits.csv")
devices <- read_csv("data/synthetic_devices.csv")

poi_types <- c("labor", "educational", "cultural", "consumption")
time_window_min <- 30   # co-presence window

# -------------------------------------------------------------------
# 1. Detect co-presence events per layer
#    Two devices are co-present in layer ℓ if they visit the same POI
#    of type ℓ within `time_window_min` minutes of each other
# -------------------------------------------------------------------

build_copresence_layer <- function(visits, layer_type, time_window_min) {

  layer_visits <- visits %>%
    filter(poi_type == layer_type) %>%
    select(device_id, poi_id, timestamp, home_ses)

  # Self-join on poi_id to find co-occurrences
  # Keep only cross-SES dyads (low device, high neighbor)
  layer_visits %>%
    inner_join(layer_visits, by = "poi_id", suffix = c("_i", "_j"),
               relationship = "many-to-many") %>%
    filter(
      device_id_i != device_id_j,
      home_ses_i == "low",
      home_ses_j == "high",
      abs(as.numeric(difftime(timestamp_i, timestamp_j, units = "mins"))) <= time_window_min
    ) %>%
    distinct(device_id_i, device_id_j) %>%
    mutate(layer = layer_type)
}

cat("Building co-presence layers...\n")
edges_by_layer <- map_dfr(poi_types, ~build_copresence_layer(visits, .x, time_window_min))

cat("Co-presence edges by layer:\n")
print(count(edges_by_layer, layer))

# -------------------------------------------------------------------
# 2. Compute SFB score per low-SES device
#    SFB_i = (sum_j sum_ℓ g^ℓ_ij / L) / (sum_j 1{sum_ℓ g^ℓ_ij > 0})
# -------------------------------------------------------------------

L <- length(poi_types)

# For each dyad, count how many layers they share
dyad_layers <- edges_by_layer %>%
  group_by(device_id_i, device_id_j) %>%
  summarise(
    n_shared_layers = n_distinct(layer),
    .groups = "drop"
  )

sfb_scores <- dyad_layers %>%
  group_by(device_id_i) %>%
  summarise(
    # Numerator: sum of (shared layers / L) across all high-SES neighbors
    sfb_numerator   = sum(n_shared_layers / L),
    # Denominator: number of unique high-SES neighbors (in any layer)
    n_unique_neighbors = n_distinct(device_id_j),
    sfb = sfb_numerator / n_unique_neighbors,
    # Also store total contact volume (to separate from SFB effect)
    total_contacts = sum(n_shared_layers),
    .groups = "drop"
  ) %>%
  rename(device_id = device_id_i)

cat("\nSFB score distribution (low-SES devices):\n")
print(summary(sfb_scores$sfb))

# -------------------------------------------------------------------
# 3. Simulate mobility outcome
#    In real data: change in workplace Census Tract SES quintile over 12 months
#    Here: injected as a threshold process to validate the pipeline
#
#    P(mobility) = logistic(β0 + β1*SFB + β2*contacts) with a threshold at SFB > 0.4
# -------------------------------------------------------------------

sfb_scores <- sfb_scores %>%
  left_join(select(devices, device_id, ses_quintile), by = "device_id") %>%
  mutate(
    # Injected DGP: threshold effect at SFB ~ 0.40
    log_odds = -2.5 + 6.0 * sfb + 0.002 * total_contacts,
    p_mobile  = plogis(log_odds),
    mobile    = rbinom(n(), 1, p_mobile)
  )

cat("\nMobility rate by SFB tercile:\n")
sfb_scores %>%
  mutate(sfb_tercile = ntile(sfb, 3)) %>%
  group_by(sfb_tercile) %>%
  summarise(
    mean_sfb    = round(mean(sfb), 3),
    mobility_rt = round(mean(mobile), 3),
    n           = n()
  ) %>%
  print()

# -------------------------------------------------------------------
# 4. Models: SFB vs. contact volume
# -------------------------------------------------------------------

cat("\n--- Model 1: Contact volume only ---\n")
m1 <- glm(mobile ~ total_contacts, data = sfb_scores, family = binomial)
print(summary(m1)$coefficients)

cat("\n--- Model 2: SFB only ---\n")
m2 <- glm(mobile ~ sfb, data = sfb_scores, family = binomial)
print(summary(m2)$coefficients)

cat("\n--- Model 3: SFB + contact volume ---\n")
m3 <- glm(mobile ~ sfb + total_contacts, data = sfb_scores, family = binomial)
print(summary(m3)$coefficients)

cat("\nPseudo-R2 (McFadden):\n")
cat("  Volume only:", round(1 - logLik(m1)/logLik(glm(mobile ~ 1, data = sfb_scores, family = binomial)), 3), "\n")
cat("  SFB only:   ", round(1 - logLik(m2)/logLik(glm(mobile ~ 1, data = sfb_scores, family = binomial)), 3), "\n")
cat("  SFB + vol:  ", round(1 - logLik(m3)/logLik(glm(mobile ~ 1, data = sfb_scores, family = binomial)), 3), "\n")

# -------------------------------------------------------------------
# 5. Quick visualization: SFB distribution and mobility gradient
# -------------------------------------------------------------------

p1 <- ggplot(sfb_scores, aes(x = sfb)) +
  geom_histogram(bins = 30, fill = "#2c7bb6", color = "white", alpha = 0.85) +
  geom_vline(xintercept = 1/L, linetype = "dashed", color = "gray40") +
  labs(
    title = "Distribution of Spatial Functional Bandwidth (SFB)",
    subtitle = paste0("Dashed line = minimum SFB (1/L = ", round(1/L, 2), ", single-layer contacts only)"),
    x = "SFB score", y = "Count"
  ) +
  theme_minimal(base_size = 13)

p2 <- sfb_scores %>%
  mutate(sfb_bin = cut(sfb, breaks = seq(0, 1, by = 0.1))) %>%
  group_by(sfb_bin) %>%
  summarise(mobility_rate = mean(mobile), n = n(), .groups = "drop") %>%
  filter(!is.na(sfb_bin)) %>%
  ggplot(aes(x = sfb_bin, y = mobility_rate)) +
  geom_col(fill = "#d7191c", alpha = 0.8) +
  geom_hline(yintercept = mean(sfb_scores$mobile), linetype = "dashed", color = "gray40") +
  labs(
    title = "Mobility Rate by SFB Score",
    subtitle = "Dashed line = overall mobility rate",
    x = "SFB score (binned)", y = "Pr(upward mobility)"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("docs/sfb_distribution.png", p1, width = 7, height = 4, dpi = 150)
ggsave("docs/sfb_mobility_gradient.png", p2, width = 7, height = 4, dpi = 150)

# Save scores
write_csv(sfb_scores, "data/sfb_scores.csv")
cat("\nDone. Scores saved to data/sfb_scores.csv\n")
cat("Plots saved to docs/\n")

# TODO: add spatial autocorrelation diagnostics (Moran's I on residuals)
# TODO: threshold detection via segmented regression (Davies test)
