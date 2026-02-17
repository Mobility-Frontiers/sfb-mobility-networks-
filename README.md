# Spatial Functional Bandwidth and Class Mobility Frontiers

> *Multiplex co-presence networks as filters of social mobility*

---

## Overview

This repository contains the research infrastructure for an ongoing project examining whether the **functional diversity** of inter-class spatial contact — not its volume — determines the diffusion of class mobility opportunities in urban settings.

The central argument: urban spaces are not functionally equivalent as channels for the transmission of mobility-enabling resources. A co-presence event in a consumption space (a mall) does not resolve the same uncertainty as one in a workplace, an educational institution, or a civic space. Each institutional domain addresses a distinct, orthogonal dimension of the uncertainty facing individuals attempting to cross class boundaries — legitimacy, technical capacity, and binding social commitment. When these dimensions are not simultaneously addressed, upward mobility does not occur regardless of the total volume of inter-class contact.

We formalize this as **Spatial Functional Bandwidth (SFB)**: the average functional diversity of inter-class co-presence events, measured across institutionally distinct spatial layers.

---

## Theoretical Background

The project bridges three bodies of literature:

**1. Stratification and the neighborhood effects debate**  
Since Chetty et al. (2014), we know that place matters for intergenerational mobility. Yet the mechanism remains a black box. The dominant peer effects hypothesis treats inter-class contacts as qualitatively equivalent — proximity alone is assumed to transmit advantage. Our framework challenges this assumption directly.

**2. Multiplex network theory and complex contagion**  
Chandrasekhar, Golub & Jackson (2025) demonstrate that network layers are not functionally interchangeable: their correlation structure shapes diffusion in non-monotonic ways, and specific layers outperform others in predicting behavioral adoption. Shi, Airoldi & Christakis (2025) show that what matters is not overlap volume but each layer's contribution to non-redundant contagion pathways (*network torque*). Neither paper, however, provides a theoretical account of *why* specific layers are functionally distinct — our concept of **functional non-substitutability** fills that gap.

**3. Urban sociology and spatial segregation**  
The literature on segregation has documented that individuals of different classes increasingly inhabit separate institutional worlds. Our contribution is to show that it is the *institutional type* of spatial mixing — not its mere occurrence — that determines whether mobility-enabling resources can flow across class boundaries.

---

## Core Concept: Spatial Functional Bandwidth (SFB)

For each individual device *i*, SFB is defined as the average fraction of institutional layers shared with inter-class neighbors:

$$SFB_i = \frac{\sum_j \sum_\ell g^\ell_{ij} / L}{\sum_j \mathbf{1}\left\{\sum_\ell g^\ell_{ij} > 0\right\}}$$

Where:
- $\ell \in \{$labor, educational, cultural/civic, consumption$\}$ are the institutional layers
- $g^\ell_{ij} = 1$ if devices *i* and *j* co-occur in a POI of type $\ell$
- The denominator counts unique inter-class neighbors across any layer

SFB = 1 when every inter-class neighbor is shared across all institutional layers. SFB = 1/L when contacts are maximally non-overlapping across layers (minimum functional redundancy).

---

## Hypotheses

**H1 — Functional non-substitutability**: SFB predicts intragenerational class mobility beyond the total volume of inter-class contacts. Individuals with the same number of inter-class contacts but different institutional diversity will show distinct mobility trajectories.

**H2 — Activation threshold**: There exists a nonlinear effect: class mobility requires SFB above a critical threshold. Below that threshold, the volume of inter-class contacts does not predict mobility — consistent with complex contagion dynamics (Centola & Macy, 2007; Granovetter, 1978).

**H3 — Asymmetric mobility**: The SFB effect is asymmetric. Upward mobility requires higher functional bandwidth than advantage reproduction — because the uncertainty facing upwardly mobile individuals is multidimensional in ways that advantage reproduction is not.

---

## Methodology

### Data

The project uses device-level GPS mobility data (US coverage) linked to:
- **American Community Survey (ACS)**: Census Tract-level SES indicators for residential and workplace classification
- **SafeGraph/Spectus POI categories** (NAICS codes): Institutional classification of visited places
- **Longitudinal panel structure**: Repeated observations enabling trajectory analysis of workplace-class transitions

### Pipeline

```
GPS pings
    └── Stop detection & home/work inference
            └── POI-type classification (4 institutional layers)
                    └── Co-presence network construction (per layer)
                            └── SFB score computation (per device)
                                    └── Class mobility outcome linkage (ACS)
                                            └── Threshold regression models
```

### Analytical Strategy

1. **Multiplex co-presence network construction**: Devices sharing the same POI within a 30-minute window are linked in that layer. This produces four directed, weighted networks per metropolitan area.

2. **SES classification**: Home location → Census Tract → ACS income quintile. Workplace → POI Census Tract → occupational class proxy.

3. **SFB computation**: For each low-SES device, compute the institutional diversity of its high-SES contacts using the formula above.

4. **Mobility operationalization**: Change in workplace Census Tract SES quintile over a 12-month window as the primary outcome variable.

5. **Threshold detection**: Nonparametric regression and simulation-based threshold models to detect whether SFB effects are nonlinear, following the complex contagion framework.

---

## Repository Structure

```
sfb-mobility-networks/
├── R/
│   ├── 01_stopdetection.R        # GPS ping processing and stop inference
│   ├── 02_poi_classification.R   # Institutional layer assignment
│   ├── 03_network_construction.R # Multiplex co-presence network builder
│   ├── 04_sfb_score.R            # Spatial Functional Bandwidth computation
│   ├── 05_ses_linkage.R          # ACS linkage and class classification
│   └── 06_threshold_models.R     # Mobility outcome models
├── synthetic/
│   ├── simulate_gps.R            # Synthetic GPS trajectory generator
│   └── synthetic_demo.R          # Full pipeline demo on synthetic data
├── data/
│   └── .gitkeep                  # GPS data not stored here (privacy)
├── docs/
│   └── theoretical_framework.md  # Extended theoretical background
└── README.md
```

---

## Preliminary Results (Synthetic Data)

The `synthetic/` folder contains a pipeline demonstration using simulated GPS trajectories calibrated to reproduce the structural properties of commercial mobility datasets. Preliminary results on synthetic data confirm that the SFB pipeline is computationally feasible at scale and that the threshold detection method recovers injected nonlinearities in the simulated data.

Full results on real GPS data pending data access.

---

## Team

**Roberto Cantillán** — PhD Candidate in Sociology, Pontificia Universidad Católica de Chile. Network science, social stratification, labor market dynamics. [`rcantillan`](https://github.com/rcantillan)

**Mauricio Bucca** (PI) — Assistant Professor of Sociology, Pontificia Universidad Católica de Chile. Social mobility, inequality, computational social science.

---

## Related Work

- Cantillán, R. (in prep). *Strategic Multiplexity and Threshold Dynamics in Urban Protest*. Working paper.
- Chandrasekhar, A., Chaudhary, V., Golub, B., & Jackson, M.O. (2025). *Multiplexing in Networks and Diffusion*. SSRN Working Paper.
- Shi, Y., Airoldi, E.M., & Christakis, N.A. (2025). *Multiplex Networks Provide Structural Pathways for Social Contagion in Rural Social Networks*. arXiv:2510.18280.
- Chetty, R., Hendren, N., Kline, P., & Saez, E. (2014). Where is the land of opportunity? *Quarterly Journal of Economics*, 129(4), 1553–1623.
- Centola, D., & Macy, M. (2007). Complex Contagions and the Weakness of Long Ties. *American Journal of Sociology*, 113(3), 702–734.

---

## License

MIT License. All code is open-source and designed for reproducibility across different GPS mobility datasets.
