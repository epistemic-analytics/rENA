# ENA: R and Python Side-by-Side

> **Data:** `rs.data.csv` — 3,824 rows, 96 units (UserName × Condition × GroupName),
> 6 codes, conversations segmented by Condition × GroupName.
>
> **Note on column names:** `read.csv()` converts spaces to dots in R
> (`Technical Constraints` → `Technical.Constraints`). Python/pandas preserves spaces.

---

## 1. Setup

| | R | Python |
|---|---|---|
| **Package** | `rENA` | `qe-ena`, `import ena` (+ `qe-lib`, `import qe`) |
| **Install** | `devtools::install("R/")` from libqe root, then `devtools::install(".")` | `pip install -e path/to/libqe/python && pip install -e path/to/rENA/python` |

**R**
```r
library(rENA)

rs <- read.csv("inst/extdata/rs.data.csv")

codes        <- c("Data", "Technical.Constraints", "Performance.Parameters",
                  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units        <- c("UserName", "Condition", "GroupName")
conversation <- c("Condition", "GroupName")
```

**Python**
```python
import pandas as pd
import numpy as np
from ena import (ENA, accumulate,
                   mean_rotation, generalized_rotation,
                   regression_rotation, regression_rotation_2)

rs = pd.read_csv("inst/extdata/rs.data.csv")

CODES = [
  "Data", "Technical Constraints", "Performance Parameters",
  "Client and Consultant Requests", "Design Reasoning", "Collaboration"
]

# Build unit and conversation keys from multiple columns
rs["unit_key"] = rs["UserName"] + "_" + rs["Condition"] + "_" + rs["GroupName"]
rs["convo_key"] = rs["Condition"] + "_" + rs["GroupName"]
```

---

## 2. Basic ENA Model

Window = 4 lines back, binary co-occurrence, sphere normalization, SVD rotation.

**R**
```r
# Simple form
model <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  model()

# Granular form (equivalent)
model <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate() |>
  project() |>
  optimize()
```

**Python**

Three equivalent styles — pick whichever reads most naturally:
```python
# Style 1 — one-liner (accumulate + model in a single call)
model = ENA().fit(rs, "unit_key", "convo_key", CODES, window_size=4)

# Style 2 — constructor style (data up front, modeling options at fit time)
model = ENA(rs, "unit_key", "convo_key", CODES).fit()
model = ENA(rs, "unit_key", "convo_key", CODES).fit(rotation=mean_rotation(g1, g2))

# Style 3 — chain style (closest to the R pipe)
model = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit()
model = (ENA()
           .accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)
           .fit(rotation=generalized_rotation(x_var)))
```

> **Both produce:** 96 units × 15 connections.  
> Connection names follow column-major upper-triangle order:  
> `Data & Technical.Constraints`, `Data & Performance.Parameters`, `Technical.Constraints & Performance.Parameters`, …

---

## 3. Accessing Results

### 3a. Normalized adjacency vectors (line weights)

**R**
```r
# data.table with metadata columns + 15 connection columns
line_weights <- model$line.weights

# Numeric matrix only
lw_matrix <- as.matrix(
  line_weights[, !colnames(line_weights) %in% c("ENA_UNIT","UserName","Condition","GroupName")]
)
# shape: 96 × 15
```

**Python**
```python
# numpy array, shape (96, 15)
lw_matrix = model.normed_networks_

# Connection labels
model.connection_names_
# → ['Data&Technical Constraints', 'Data&Performance Parameters', ...]
```

### 3b. Unit positions (centroids in ENA space)

**R**
```r
# data.table with SVD1, SVD2 columns
centroids <- model$points.rotated

# First unit
centroids[1, c("SVD1", "SVD2")]
# SVD1: 0.0563   SVD2: 0.1016
```

**Python**
```python
# numpy array, shape (96, 2)
centroids = model.centroids_

# First unit
centroids[0]
# → [ 0.0563,  0.1016]

# With unit labels
import pandas as pd
pd.DataFrame(model.centroids_, index=model.units_, columns=["SVD1","SVD2"])
```

### 3c. Node positions

**R**
```r
# matrix, shape (6 codes × 2 dims), rownames = code names
node_pos <- model$rotation.set$node.positions

node_pos["Data", ]
# SVD1: -1.0495   SVD2: -0.2738
```

**Python**
```python
# numpy array, shape (6, 2) — rows in CODES order
node_pos = model.positions_

pd.DataFrame(model.positions_, index=CODES, columns=["SVD1","SVD2"])
#                                    SVD1    SVD2
# Data                             -1.0495 -0.2738
# Technical Constraints             1.8661  0.8065
# ...
```

### 3d. Raw (un-normalized) adjacency vectors

**R**
```r
# data.table, metadata + 15 connection columns
raw <- model$enadata$connection.counts
```

**Python**
```python
# numpy array, shape (96, 15)
raw = model.networks_

# Or access directly from the accumulation object
raw = model.accum_.networks_
```

### 3e. Accumulation as a standalone object

**R** — the accumulate step can be kept as its own object:
```r
accum <- rs |> accumulate(units, codes, conversation, default_window = 4)
# accum is a reusable object — pipe into model(), sphere_norm(), etc.
```

**Python**
```python
from ena import accumulate, ENAAccumulation

accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)

accum.networks_          # (96, 15) raw co-occurrence matrix
accum.units_             # unit labels in first-appearance order
accum.codes_             # code names
accum.connection_names_  # connection labels
accum.meta               # DataFrame: one row per unit, unit-level columns

# Reuse the same accumulation with different models/rotations
model_svd  = ENA().fit(accum)
model_mr   = ENA().fit(accum, rotation=mean_rotation(g1_mask, g2_mask))
model_gmr  = ENA().fit(accum, rotation=generalized_rotation(x_var))
```

---

## 4. Window Size Variations

### Larger window (8 lines back)

**R**
```r
model8 <- rs |>
  accumulate(units, codes, conversation, default_window = 8) |>
  model()
```

**Python**
```python
model8 = ENA().fit(rs, "unit_key", "convo_key", CODES, window_size=8)
```

### Infinite window (whole-conversation accumulation)

**R**
```r
model_inf <- rs |>
  accumulate(units, codes, conversation, default_window = Inf) |>
  model()
```

**Python**
```python
import sys
model_inf = ENA().fit(
    rs, "unit_key", "convo_key", CODES,
    window_size = sys.maxsize   # entire conversation
)
```

### Forward window (bidirectional)

**R**
```r
model_bi <- rs |>
  accumulate(units, codes, conversation,
             default_window = 4, window_forward = 2) |>
  model()
```

**Python**
```python
model_bi = ENA().fit(
    rs, "unit_key", "convo_key", CODES,
    window_size    = 4,
    window_forward = 2
)
```

---

## 5. Weighted (Non-Binary) Co-occurrence

**R**
```r
model_wtd <- rs |>
  accumulate(units, codes, conversation,
             default_window = 4, weight.by = "sum") |>
  model()
```

**Python**
```python
model_wtd = ENA().fit(
    rs, "unit_key", "convo_key", CODES,
    window_size = 4,
    binary      = False   # preserve raw co-occurrence counts
)
```

---

## 6. Group Comparison

### Split model by group

**R**
```r
fg <- model$line.weights[model$line.weights$Condition == "FirstGame",  ]
sg <- model$line.weights[model$line.weights$Condition == "SecondGame", ]

fg_mean <- colMeans(fg[, codes_adj])   # mean network per group
sg_mean <- colMeans(sg[, codes_adj])
subtracted <- fg_mean - sg_mean         # network subtraction
```

**Python**
```python
import numpy as np

# Attach condition back to results
conditions = rs.drop_duplicates("unit_key").set_index("unit_key")["Condition"]

fg_mask = [conditions.get(u, "") == "FirstGame"  for u in model.units_]
sg_mask = [conditions.get(u, "") == "SecondGame" for u in model.units_]

fg_mean = model.normed_networks_[fg_mask].mean(axis=0)
sg_mean = model.normed_networks_[sg_mask].mean(axis=0)
subtracted = fg_mean - sg_mean           # network subtraction
```

---

## 7. Rotations

All rotation methods follow the same pattern: define one or two priority axes, then fill the remaining dimensions via SVD of the complement subspace (QR + SVD, producing a full orthogonal rotation matrix).

> **Setup for all rotation examples below**
>
> ```python
> # Accumulate once — reuse across all rotation variants below.
> # This avoids re-counting co-occurrences for every model.
> accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)
>
> # Attach unit-level metadata in unit order — needed by rotation factories
> meta = (
>     rs.drop_duplicates("unit_key")
>       .set_index("unit_key")
>       .reindex(accum.units_)
>       .reset_index()
> )
> ```

### 7a. Means rotation — maximise variance between two group means

**R**
```r
model_mr <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.mean,
         rs$Condition == "FirstGame",
         rs$Condition == "SecondGame") |>
  project() |>
  optimize()
```

**Python**
```python
model_mr = ENA().fit(
    accum,
    rotation=mean_rotation(
        meta["Condition"] == "FirstGame",
        meta["Condition"] == "SecondGame",
    )
)
```

> Axis 1 = normalised difference of group mean networks; remaining axes from SVD of the complement.

---

### 7b. Generalised Means Rotation (GMR)

Axis 1 is derived from a predictor variable. Numeric predictor → OLS regression axis; categorical predictor → first eigenvector of the between-group scatter matrix.

#### Continuous predictor

**R**
```r
model_gmr <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.generalized, rs$CONFIDENCE.Change) |>
  project() |>
  optimize()
```

**Python**
```python
model_gmr = ENA().fit(
    accum,
    rotation=generalized_rotation(meta["CONFIDENCE.Change"].astype(float))
)
```

#### Categorical predictor (all groups, via scatter matrix)

**R**
```r
model_gmr_cat <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.generalized, rs$Condition) |>
  project() |>
  optimize()
```

**Python**
```python
model_gmr_cat = ENA().fit(
    accum,
    rotation=generalized_rotation(meta["Condition"])  # dtype=object → categorical path
)
```

#### Categorical predictor — explicit two-group mean difference

**R**
```r
model_gmr2 <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.generalized,
         rs$Condition == "FirstGame",
         rs$Condition == "SecondGame") |>
  project() |>
  optimize()
```

**Python**
```python
model_gmr2 = ENA().fit(
    accum,
    rotation=generalized_rotation(
        meta["Condition"],
        select_2_groups=("FirstGame", "SecondGame"),
    )
)
```

#### Two-axis GMR (x and y predictors)

**R**
```r
model_gmr_xy <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.generalized,
         rs$CONFIDENCE.Change, rs$Condition) |>
  project() |>
  optimize()
```

**Python**
```python
model_gmr_xy = ENA().fit(
    accum,
    rotation=generalized_rotation(
        x_var=meta["CONFIDENCE.Change"].astype(float),
        y_var=meta["Condition"],
    )
)
```

---

### 7c. Regression rotation — networks as dependent variable (V ~ x)

Axis 1 = normalised multivariate OLS slope of `networks ~ predictor`.

**R**
```r
condition_bin <- as.integer(rs$Condition == "FirstGame")

model_reg <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.hena.regression, condition_bin) |>
  project() |>
  optimize()
```

**Python**
```python
condition_bin = (meta["Condition"] == "FirstGame").astype(float).to_numpy()

model_reg = ENA().fit(accum, rotation=regression_rotation(condition_bin))
```

---

### 7d. Regression rotation 2 — predictor as dependent variable (x ~ V)

Axis 1 = normalised OLS slopes from regressing the predictor *on* the networks.

**R**
```r
model_reg2 <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(ena.rotate.by.hena.regression_2, condition_bin) |>
  project() |>
  optimize()
```

**Python**
```python
model_reg2 = ENA().fit(accum, rotation=regression_rotation_2(condition_bin))
```

---

### 7e. Custom / pre-computed rotation matrix

Pass any orthogonal `(n_connections × k)` matrix directly.

**R**
```r
# Build or load your own rotation matrix
custom_rot <- matrix(..., nrow = 15, ncol = 2)

model_custom <- rs |>
  accumulate(units, codes, conversation, default_window = 4) |>
  sphere_norm() |>
  center() |>
  rotate(custom_rot) |>
  project() |>
  optimize()
```

**Python**
```python
custom_rot = np.array(...)   # shape (15, 2) for 6 codes

model_custom = ENA().fit(accum, rotation=custom_rot)
```

---

### Rotation quick reference

| Rotation | R | Python |
|---|---|---|
| SVD (default) | *(default)* | `rotation=None` |
| Means | `ena.rotate.by.mean` | `mean_rotation(g1_mask, g2_mask)` |
| GMR continuous | `ena.rotate.by.generalized` | `generalized_rotation(x_var)` |
| GMR categorical | `ena.rotate.by.generalized` | `generalized_rotation(x_var)` |
| GMR two-group | `ena.rotate.by.generalized` (two masks) | `generalized_rotation(x_var, select_2_groups=(...))` |
| GMR two-axis | `ena.rotate.by.generalized` (two vars) | `generalized_rotation(x_var, y_var=...)` |
| Regression (V~x) | `ena.rotate.by.hena.regression` | `regression_rotation(x_var)` |
| Regression (x~V) | `ena.rotate.by.hena.regression_2` | `regression_rotation_2(x_var)` |
| Custom matrix | `rotation.set=list(rotation=mat)` | `rotation=my_matrix` |

---

## 8. Correlation (model fit)

**R**
```r
# Pearson r between unit positions and centroids, per dimension
cors <- ena.correlations(model)
# returns matrix: dims × [r, ci_lower, ci_upper]
```

**Python**
```python
from qe import modeling

cors = modeling.ena_correlation(
    model.points_,     # projected unit positions
    model.centroids_,  # solved centroids
    conf_level = 0.95
)
# numpy array (2 × 3): [r, ci_lower, ci_upper] per dim
```

---

## 9. Quick Reference

| Concept | R | Python |
|---|---|---|
| Accumulate only | `data \|> accumulate(...)` | `accumulate(data, units, convos, codes)` |
| Fit — one-liner | `data \|> accumulate(...) \|> model()` | `ENA().fit(data, units, convos, codes)` |
| Fit — constructor | *(same as above)* | `ENA(data, units, convos, codes).fit()` |
| Fit — chain | `accumulate() \|> sphere_norm() \|> ... \|> optimize()` | `ENA().accumulate(data, ...).fit()` |
| Fit — from accum | `accum \|> model()` | `ENA().fit(accum)` |
| Window back | `default_window=4` | `window_size=4` |
| Window forward | `window_forward=2` | `window_forward=2` |
| Infinite window | `default_window=Inf` | `window_size=sys.maxsize` |
| Binary mode | `weight.by="binary"` | `binary=True` |
| Weighted mode | `weight.by="sum"` | `binary=False` |
| Normalization | `sphere_norm()` | `norm="sphere"` |
| Skip-sphere norm | `skip_sphere_norm()` | `norm="skip_sphere"` |
| Dimensions | `dimensions=2` | `dims=2` |
| **Rotation — SVD** | `rotate()` | `rotation=None` |
| **Rotation — means** | `rotate(ena.rotate.by.mean, g1, g2)` | `rotation=mean_rotation(g1, g2)` |
| **Rotation — GMR** | `rotate(ena.rotate.by.generalized, x)` | `rotation=generalized_rotation(x)` |
| **Rotation — regression** | `rotate(ena.rotate.by.hena.regression, x)` | `rotation=regression_rotation(x)` |
| **Rotation — regression 2** | `rotate(ena.rotate.by.hena.regression_2, x)` | `rotation=regression_rotation_2(x)` |
| **Rotation — custom matrix** | `rotate(mat)` | `rotation=my_ndarray` |
| Raw networks | `model$enadata$connection.counts` | `model.networks_` |
| Normed networks | `model$line.weights` | `model.normed_networks_` |
| Unit centroids | `model$points.rotated` | `model.centroids_` |
| Node positions | `model$rotation.set$node.positions` | `model.positions_` |
| Rotation matrix | `model$rotation.set$rotation` | `model.rotation_` |
| Connection names | `colnames(model$line.weights)[4:18]` | `model.connection_names_` |
| Unit labels | `model$enadata$unit.names` | `model.units_` |
| Correlation | `ena.correlations(model)` | `modeling.ena_correlation(...)` |

---

## Format note

This document is markdown. For a **runnable** version:
- A **Jupyter notebook** with R kernel (`IRkernel`) and Python kernel lets you run both languages 
  in the same file and see outputs inline — ideal for verification.
- Generate with: `jupytext --to notebook ena-r-python-comparison.md`  
  (requires `pip install jupytext`)
