# rENA <img src="man/figures/logo.png" align="right" alt="" width="120" />

[![cran status](https://www.r-pkg.org/badges/version-ago/rENA)](https://cran.r-project.org/package=rENA) 
[![cran downloads](https://cranlogs.r-pkg.org/badges/grand-total/rENA)](https://cranlogs.r-pkg.org/badges/grand-total/rENA) 
[![pipeline status](https://gitlab.com/epistemic-analytics/qe-packages/rENA/badges/main/pipeline.svg)](https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/commits/main)
[![coverage report](https://gitlab.com/epistemic-analytics/qe-packages/rENA/badges/main/coverage.svg)](https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/commits/main)

## What is ENA?

[Epistemic Network Analysis](https://www.epistemicnetwork.org/) (ENA) is a method for identifying and quantifying connections among elements in coded data and representing them in dynamic network models. A key feature of the ENA tool is that it enables researchers to compare different networks, both visually and through summary statistics that reflect the weighted structure of connections.

Researchers have used ENA to analyze phenomena including: cognitive connections students make while solving complex problems; interactions among brain regions in fMRI data; social gaze coordination; integration of operative skills during surgical procedures; and many others.

This repository provides ENA for both **R** (`rENA`) and **Python** (`pyena`).

---

## Installation

### R — from CRAN

```r
install.packages("rENA")
```

### R — development version

```r
install.packages("rENA", repos = c("https://rena.qe-libs.org/cran/", "https://cran.rstudio.org"))
```

### Python

`pyena` depends on `pylibqe` (the shared C++ math layer). Install both from source:

```bash
pip install -e path/to/libqe/python    # pylibqe
pip install -e path/to/rENA/python     # pyena
```

---

## Quick Start

### R

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

### Python

```python
import pandas as pd
from pyena import ENA, accumulate

rs = pd.read_csv("inst/extdata/rs.data.csv")

CODES = ["Data", "Technical Constraints", "Performance Parameters",
         "Client and Consultant Requests", "Design Reasoning", "Collaboration"]

rs["unit_key"] = rs["UserName"] + "_" + rs["Condition"] + "_" + rs["GroupName"]
rs["convo_key"] = rs["Condition"] + "_" + rs["GroupName"]

# Style 1 — one-liner
model = ENA().fit(rs, "unit_key", "convo_key", CODES)

# Style 2 — constructor (data up front, options at fit time)
model = ENA(rs, "unit_key", "convo_key", CODES).fit()

# Style 3 — chain (closest to the R pipe)
model = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit()
```

---

## Accessing Results

### R

```r
model$line.weights        # normalised adjacency vectors (units × connections)
model$points.rotated      # unit positions in ENA space
model$rotation.set$node.positions  # code node positions
```

### Python

```python
model.normed_networks_    # normalised adjacency vectors  (n_units × n_connections)
model.centroids_          # unit positions in ENA space   (n_units × dims)
model.positions_          # code node positions           (n_codes × dims)
model.networks_           # raw (un-normalised) adjacency vectors
model.units_              # unit labels in order
model.connection_names_   # e.g. ["Data&Technical Constraints", ...]
```

---

## Separate Accumulation

The accumulation step (counting co-occurrences) can be run independently of modeling.
This is useful when you want to inspect raw networks, export them, or reuse the same
accumulation with multiple rotation methods.

### R

```r
accum <- RS.data |> accumulate(units, codes, conversation, default_window = 4)
# then pipe into model(), sphere_norm(), etc. separately
```

### Python

```python
from pyena import accumulate

accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)

accum.networks_          # (96 × 15) raw co-occurrence matrix
accum.units_             # unit labels
accum.connection_names_  # connection labels
accum.meta               # per-unit metadata DataFrame

# Reuse the same accumulation with different rotations — no re-counting
from pyena import mean_rotation, generalized_rotation

model_svd = ENA().fit(accum)
model_mr  = ENA().fit(accum, rotation=mean_rotation(g1_mask, g2_mask))
model_gmr = ENA().fit(accum, rotation=generalized_rotation(meta["Condition"]))
```

---

## Rotation Methods

All rotation methods are available in both R and Python.

| Rotation | R | Python |
|---|---|---|
| SVD (default) | `rotate()` | `rotation=None` |
| Means | `rotate(ena.rotate.by.mean, g1, g2)` | `mean_rotation(g1, g2)` |
| Generalised (GMR) | `rotate(ena.rotate.by.generalized, x)` | `generalized_rotation(x_var)` |
| Regression (V ~ x) | `rotate(ena.rotate.by.hena.regression, x)` | `regression_rotation(x_var)` |
| Regression (x ~ V) | `rotate(ena.rotate.by.hena.regression_2, x)` | `regression_rotation_2(x_var)` |
| Custom matrix | `rotate(mat)` | `rotation=my_ndarray` |

### R

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

### Python

```python
from pyena import ENA, mean_rotation, generalized_rotation, regression_rotation

# Attach unit-level metadata (needed by rotation factories)
meta = (rs.drop_duplicates("unit_key")
          .set_index("unit_key")
          .reindex(model.units_)
          .reset_index())

# Means rotation
model_mr = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
    rotation=mean_rotation(
        meta["Condition"] == "FirstGame",
        meta["Condition"] == "SecondGame",
    )
)

# Generalised rotation — categorical
model_gmr = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
    rotation=generalized_rotation(meta["Condition"])
)

# Regression rotation
condition_bin = (meta["Condition"] == "FirstGame").astype(float).to_numpy()
model_reg = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
    rotation=regression_rotation(condition_bin)
)
```

---

## Window Options

| Option | R | Python |
|---|---|---|
| Window back | `default_window=4` | `window_size=4` |
| Window forward | `window_forward=2` | `window_forward=2` |
| Infinite window | `default_window=Inf` | `window_size=sys.maxsize` |
| Binary co-occurrence | `weight.by="binary"` | `binary=True` |
| Weighted co-occurrence | `weight.by="sum"` | `binary=False` |

---

## Further Reading

- Full R/Python side-by-side reference: [`docs/ena-r-python-comparison.md`](docs/ena-r-python-comparison.md)
- [ENA resources page](https://www.epistemicnetwork.org/resources/)
- [Epistemic Analytics](https://www.epistemicnetwork.org/)
