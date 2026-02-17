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

**1. Stratification, neighborhood effects, and the limits of exposure**  
Chetty, Jackson et al. (2022a) established — using 21 billion Facebook friendships — that *economic connectedness* (EC), the share of high-SES friends among low-SES individuals, is the single strongest predictor of upward income mobility across U.S. counties, outperforming racial segregation, inequality, and educational outcomes. Their companion paper (Chetty et al. 2022b) decomposes the cross-class connection deficit into two components: *exposure* (access to high-SES individuals in shared institutional settings) and *friending bias* (lower rates of cross-class tie formation even conditional on exposure). Crucially, they find that **interaction** — not mere proximity — is what drives mobility.

This leaves a fundamental measurement gap: Facebook captures friendships as a single undifferentiated relational layer, unable to distinguish *where* or *in what institutional context* those ties form. A cross-class connection initiated at work is functionally different from one formed at a mall, and neither is equivalent to one forged in an educational or civic setting. Our framework addresses this directly: GPS data reveals co-presence in categorized institutional spaces, providing the first instrument capable of measuring the *functional composition* of cross-class interaction at urban scale.

**2. Multiplex network theory and complex contagion**  
Chandrasekhar, Golub & Jackson (2025) demonstrate that network layers are not functionally interchangeable: their correlation structure shapes diffusion in non-monotonic ways, and specific layers outperform others in predicting behavioral adoption. Shi, Airoldi & Christakis (2025) show that what matters is not overlap volume but each layer's contribution to non-redundant contagion pathways (*network torque*). Neither paper, however, provides a theoretical account of *why* specific layers are functionally distinct — our concept of **functional non-substitutability** fills that gap.

**3. Urban sociology and spatial segregation**  
The literature documents that individuals of different classes increasingly inhabit separate institutional worlds. Our contribution is to show that it is the *institutional type* of spatial mixing — not its mere occurrence — that determines whether mobility-enabling resources can flow across class boundaries. This reframes Chetty et al.'s exposure component: what matters is not just whether low- and high-SES individuals share institutional spaces, but whether they share *multiple, functionally heterogeneous* ones simultaneously.

---

## Core Concept: Spatial Functional Bandwidth (SFB)

For each individual device *i*, SFB is defined as the average fraction of institutional layers shared with inter-class neighbors:

$$SFB_i = \frac{\sum_j \sum_\ell g^\ell_{ij} / L}{\sum_j \mathbf{1}\lbrace\sum_\ell g^\ell_{ij} > 0\rbrace}$$

Where:
- $\ell \in \lbrace \text{labor, educational, cultural/civic, consumption} \rbrace$ are the institutional layers
- $g^\ell_{ij} = 1$ if devices $i$ and $j$ co-occur in a POI of type $\ell$ within a given time window
- The denominator counts unique inter-class neighbors of $i$ across any layer

$SFB_i = 1$ when every inter-class neighbor shares all institutional layers with $i$. $SFB_i = 1/L$ when contacts are maximally non-overlapping — minimum functional redundancy.

---

## Hypotheses

**H1 — Functional non-substitutability**: SFB predicts intragenerational class mobility beyond the total volume of inter-class contacts. Individuals with the same number of inter-class contacts but different institutional diversity will show distinct mobility trajectories. This extends Chetty et al.'s finding that *interaction* predicts mobility by specifying the functional composition of interaction that matters.

**H2 — Activation threshold**: There exists a nonlinear effect: class mobility requires SFB above a critical threshold. Below that threshold, the volume of inter-class contacts does not predict mobility — consistent with complex contagion dynamics (Centola & Macy, 2007; Granovetter, 1978).

**H3 — Asymmetric mobility**: The SFB effect is asymmetric. Upward mobility requires higher functional bandwidth than advantage reproduction — because the uncertainty facing upwardly mobile individuals is multidimensional in ways that advantage reproduction is not.

---

## Methodology

### Data

The project uses device-level GPS mobility data (US coverage) linked to:
- **American Community Survey (ACS)**: Census Tract-level SES indicators for residential and workplace classification
- **SafeGraph/Spectus POI categories** (NAICS codes): Institutional classification of visited places into four functional layers
- **Longitudinal panel structure**: Repeated observations enabling trajectory analysis of workplace-class transitions
- **Opportunity Atlas** (Chetty et al. 2018): County-level mobility benchmarks for outcome validation

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

The `synthetic/` folder contains a pipeline demonstration using simulated GPS trajectories calibrated to reproduce the structural properties of commercial mobility datasets. Key results on synthetic data (`N` = 600 devices, 45 days):

- **SFB predicts mobility** with McFadden R² = 0.051; contact volume alone achieves R² = 0.004 — a 12× difference, consistent with H1.
- **SFB coefficient**: β = 57.3 (SE = 12.4, *p* < 0.001); contact volume non-significant (*p* = 0.79).
- **Monotonic mobility gradient** by SFB quintile: Q1 = 21%, Q2 = 29%, Q3 = 36%, Q4 = 43%, Q5 = 56% — consistent with an activation threshold (H2).
- The pipeline correctly recovers injected structural variation by spatial mobility profile (constrained < partial < diverse), validating measurement validity.

Note: synthetic data conservatively underestimates real SFB variation, as urban spatial segregation generates larger inter-class differences than simulation parameters.

---

## Team

**Roberto Cantillán** — PhD Candidate in Sociology, Pontificia Universidad Católica de Chile. Network science, social stratification, labor market dynamics. [`rcantillan`](https://github.com/rcantillan)

**Mauricio Bucca** (PI) — Assistant Professor of Sociology, Pontificia Universidad Católica de Chile. Social mobility, inequality, computational social science. [`mebucca`](https://github.com/mebucca)

---

## Related Work

- Cantillán, R. (in prep). *Strategic Multiplexity and Threshold Dynamics in Urban Protest*. Working paper.
- Chetty, R., Jackson, M.O., Kuchler, T., Stroebel, J. et al. (2022a). Social capital I: measurement and associations with economic mobility. *Nature*, 608(7921), 108–121.
- Chetty, R., Jackson, M.O., Kuchler, T., Stroebel, J. et al. (2022b). Social capital II: determinants of economic connectedness. *Nature*, 608(7921), 122–134.
- Chandrasekhar, A., Chaudhary, V., Golub, B., & Jackson, M.O. (2025). *Multiplexing in Networks and Diffusion*. SSRN Working Paper.
- Shi, Y., Airoldi, E.M., & Christakis, N.A. (2025). Multiplex networks provide structural pathways for social contagion in rural social networks. arXiv:2510.18280.
- Chetty, R., Friedman, J., Hendren, N., Jones, M., & Porter, S. (2018). The opportunity atlas. *NBER Working Paper* 25147.
- Centola, D., & Macy, M. (2007). Complex contagions and the weakness of long ties. *American Journal of Sociology*, 113(3), 702–734.
- Granovetter, M. (1978). Threshold models of collective behavior. *American Journal of Sociology*, 83(6), 1420–1443.

---

## License

MIT License. All code is open-source and designed for reproducibility across different GPS mobility datasets.
