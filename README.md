# rENA <img src="man/figures/logo.png" align="right" alt="" width="120" />

[![cran status](https://www.r-pkg.org/badges/version-ago/rENA)](https://cran.r-project.org/package=rENA) 
[![cran downloads](https://cranlogs.r-pkg.org/badges/grand-total/rENA)](https://cranlogs.r-pkg.org/badges/grand-total/rENA) 
[![pipeline status](https://gitlab.com/epistemic-analytics/qe-packages/rENA/badges/main/pipeline.svg)](https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/commits/main)
[![coverage report](https://gitlab.com/epistemic-analytics/qe-packages/rENA/badges/main/coverage.svg)](https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/commits/main)

## What is ENA?

[Epistemic Network Analysis](https://www.epistemicnetwork.org/) (ENA) is a method for identifying and quantifying connections among elements in coded data and representing them in dynamic network models. A key feature of the ENA tool is that it enables researchers to compare different networks, both visually and through summary statistics that reflect the weighted structure of connections.

Researchers have used ENA to analyze phenomena including: cognitive connections students make while solving complex problems; interactions among brain regions in fMRI data; social gaze coordination; integration of operative skills during surgical procedures; and many others.

> **Python users:** see [`python/README.md`](python/README.md) for the `pyena` package.

---

## Installation

### From CRAN

```r
install.packages("rENA")
```

### Development version

```r
install.packages("rENA", repos = c("https://cran.qe-libs.org", "https://cran.rstudio.org"))
```

---

## Quick Start

```r
library(rENA)

codes        <- c("Data", "Technical.Constraints", "Performance.Parameters",
                  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units        <- c("UserName", "Condition", "GroupName")
conversation <- c("Condition", "GroupName")

# Simple form
model <- RS.data |>
  accumulate(units, codes, conversation, default_window = 4) |>
  model()

# Granular form (equivalent)
model <- RS.data |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate() |>
  project() |>
  optimize()
```

---

## Accessing Results

```r
model$line.weights                     # normalised adjacency vectors (units × connections)
model$points.rotated                   # unit positions in ENA space
model$rotation.set$node.positions      # code node positions
```

---

## Separate Accumulation

The accumulation step can be run independently of modeling — useful for inspecting raw
networks, exporting them, or reusing the same accumulation with multiple rotation methods.

```r
accum <- RS.data |> accumulate(units, codes, conversation, default_window = 4)

# Then pipe into model(), sphere_norm(), etc. separately
model <- accum |> sphere_norm() |> center() |> rotate() |> project() |> optimize()
```

---

## Rotation Methods

| Rotation | Function |
|---|---|
| SVD (default) | `rotate()` |
| Means | `rotate(ena.rotate.by.mean, g1, g2)` |
| Generalised (GMR) | `rotate(ena.rotate.by.generalized, x)` |
| Regression (V ~ x) | `rotate(ena.rotate.by.hena.regression, x)` |
| Regression (x ~ V) | `rotate(ena.rotate.by.hena.regression_2, x)` |
| Custom matrix | `rotate(mat)` |

```r
# Means rotation
model_mr <- RS.data |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |> center() |>
  rotate(ena.rotate.by.mean,
         RS.data$Condition == "FirstGame",
         RS.data$Condition == "SecondGame") |>
  project() |> optimize()

# Generalised rotation
model_gmr <- RS.data |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |> center() |>
  rotate(ena.rotate.by.generalized, RS.data$Condition) |>
  project() |> optimize()
```

---

## Window Options

| Option | Argument |
|---|---|
| Window back | `default_window = 4` |
| Window forward | `window_forward = 2` |
| Infinite window | `default_window = Inf` |
| Binary co-occurrence | `weight.by = "binary"` |
| Weighted co-occurrence | `weight.by = "sum"` |

---

## Further Reading

- [Trajectory models in rENA](docs/trajectory-models.md)
- [ENA resources page](https://www.epistemicnetwork.org/resources/)
- [Epistemic Analytics](https://www.epistemicnetwork.org/)
