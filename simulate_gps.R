# simulate_gps.R
# Synthetic GPS trajectory generator for SFB pipeline development
# Simulates device-level mobility patterns across institutionally typed POIs
#
# The goal is to reproduce the structural properties of commercial GPS datasets
# (Spectus/SafeGraph style) without real data. Calibrated loosely on
# US urban mobility literature (Pappalardo et al. 2015; Barbosa et al. 2018).
#
# Key design decisions:
#   - Low-SES devices vary considerably in how many POI types they visit
#     (some are spatially constrained, others are not — this is the
#     key source of variation in SFB that the pipeline needs to recover)
#   - High-SES devices visit more uniformly diverse institutional spaces
#
# RC - 2025

library(tidyverse)
library(lubridate)

set.seed(42)

# -------------------------------------------------------------------
# Parameters
# -------------------------------------------------------------------

n_devices     <- 600
n_days        <- 45
n_poi         <- 120
visit_rate    <- 5.0

poi_types       <- c("labor", "educational", "cultural", "consumption")
poi_type_shares <- c(0.28, 0.14, 0.13, 0.45)
ses_labels      <- c("low", "high")

# -------------------------------------------------------------------
# 1. POI universe
# -------------------------------------------------------------------

pois <- tibble(
  poi_id   = paste0("poi_", str_pad(1:n_poi, 3, pad = "0")),
  poi_type = sample(poi_types, n_poi, replace = TRUE, prob = poi_type_shares),
  poi_ses  = sample(ses_labels, n_poi, replace = TRUE, prob = c(0.55, 0.45)),
  lon      = runif(n_poi, -87.7, -87.5),
  lat      = runif(n_poi,  41.8,  42.0)
)

# -------------------------------------------------------------------
# 2. Devices
#    Low-SES devices get a mobility_type that drives institutional diversity.
#    This is the key source of SFB variation: within the low-SES population,
#    some individuals are spatially constrained (labor + consumption only),
#    others have partial access to educational or cultural spaces,
#    and a minority navigate all four institutional domains.
# -------------------------------------------------------------------

devices <- tibble(
  device_id = paste0("dev_", str_pad(1:n_devices, 4, pad = "0")),
  home_ses  = sample(ses_labels, n_devices, replace = TRUE, prob = c(0.60, 0.40))
) %>%
  mutate(
    ses_quintile = case_when(
      home_ses == "low"  ~ sample(1:2, n(), replace = TRUE),
      home_ses == "high" ~ sample(4:5, n(), replace = TRUE)
    ),
    mobility_type = case_when(
      home_ses == "high" ~ "diverse",
      home_ses == "low"  ~ sample(
        c("constrained", "partial", "diverse"),
        n(), replace = TRUE,
        prob = c(0.45, 0.35, 0.20)
      )
    )
  )

# -------------------------------------------------------------------
# 3. Simulate visits
# -------------------------------------------------------------------

simulate_visits <- function(device_id, home_ses, mobility_type,
                             n_days, pois, visit_rate) {
  type_probs <- switch(mobility_type,
    "constrained" = c(labor = 0.52, educational = 0.03, cultural = 0.02, consumption = 0.43),
    "partial"     = c(labor = 0.38, educational = 0.12, cultural = 0.08, consumption = 0.42),
    "diverse"     = c(labor = 0.27, educational = 0.22, cultural = 0.19, consumption = 0.32)
  )

  n_visits     <- rpois(1, visit_rate * n_days)
  poi_weights  <- type_probs[pois$poi_type]
  visited_pois <- pois[sample(nrow(pois), n_visits, replace = TRUE,
                               prob = poi_weights), ]

  tibble(
    device_id    = device_id,
    poi_id       = visited_pois$poi_id,
    poi_type     = visited_pois$poi_type,
    poi_ses      = visited_pois$poi_ses,
    timestamp    = as.POSIXct("2023-01-01") +
                   sort(runif(n_visits, 0, n_days * 86400)),
    duration_min = round(rexp(n_visits, rate = 1/40))
  )
}

visits <- devices %>%
  pmap_dfr(function(device_id, home_ses, ses_quintile, mobility_type) {
    simulate_visits(device_id, home_ses, mobility_type, n_days, pois, visit_rate)
  }) %>%
  left_join(select(devices, device_id, home_ses, ses_quintile, mobility_type),
            by = "device_id")

# -------------------------------------------------------------------
# 4. Sanity checks
# -------------------------------------------------------------------

cat("Total visit events:", nrow(visits), "\n")
cat("Avg visits per device:", round(nrow(visits) / n_devices, 1), "\n")

cat("\nVisit distribution by POI type:\n")
print(count(visits, poi_type) %>% mutate(pct = round(n / sum(n), 3)))

cat("\nVisit distribution by device SES:\n")
print(count(visits, home_ses) %>% mutate(pct = round(n / sum(n), 3)))

cat("\nLow-SES devices by mobility type:\n")
print(devices %>% filter(home_ses == "low") %>%
        count(mobility_type) %>% mutate(pct = round(n / sum(n), 3)))

# -------------------------------------------------------------------
# 5. Save
# -------------------------------------------------------------------

write_csv(visits,  "data/synthetic_visits.csv")
write_csv(pois,    "data/synthetic_pois.csv")
write_csv(devices, "data/synthetic_devices.csv")

cat("\nSynthetic data saved to data/\n")
