# pyena

Python implementation of Epistemic Network Analysis (ENA) — sister package to [`rENA`](../README.md).

`pyena` delegates all core math to [`pylibqe`](https://gitlab.com/epistemic-analytics/qe-packages/libqe),
the shared C++ library that also powers rENA.

---

## Installation

`pyena` requires `pylibqe`. Install both from the QE package index:

```bash
pip install pyENA \
  --index-url https://qe-libs.org/py/simple/ \
  --extra-index-url https://pypi.org/simple/
```

### Development install

```bash
pip install pylibqe \
  --index-url https://qe-libs.org/py/simple/ \
  --extra-index-url https://pypi.org/simple/

pip install -e ".[dev]"   # from python/ directory
```

---

## Quick Start

```python
import pandas as pd
from pyena import ENA

rs = pd.read_csv("../inst/extdata/rs.data.csv")

CODES = ["Data", "Technical.Constraints", "Performance.Parameters",
         "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration"]

rs["unit_key"] = rs["UserName"] + "_" + rs["Condition"] + "_" + rs["GroupName"]
rs["convo_key"] = rs["Condition"] + "_" + rs["GroupName"]

model = ENA().fit(rs, "unit_key", "convo_key", CODES)
```

---

## Accessing Results

```python
model.line_weights_           # normalised adjacency vectors  (n_units × n_connections)
model.row_connection_counts_  # row-level raw adjacency vectors (n_rows × n_connections)
model.centroids_              # unit positions in ENA space   (n_units × dims)
model.rotation_nodes_         # code node positions           (n_codes × dims)
model.connection_counts_      # raw unit adjacency vectors    (n_units × n_connections)
model.unit_labels_            # unit labels in order
model.connection_names_       # e.g. ["Data & Technical.Constraints", ...]
```

---

## Separate Accumulation

```python
from pyena import ENA, accumulate

accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)

accum.connection_counts_      # raw unit co-occurrence matrix
accum.row_connection_counts_  # raw row co-occurrence matrix
accum.unit_labels_            # unit labels
accum.connection_names_       # connection labels
accum.meta                    # per-unit metadata DataFrame

# Reuse the same accumulation with different rotations
from pyena import mean_rotation, generalized_rotation

model_svd = ENA().fit(accum)
model_mr  = ENA().fit(accum, rotation=mean_rotation(g1_mask, g2_mask))
model_gmr = ENA().fit(accum, rotation=generalized_rotation(meta["Condition"]))
```

---

## Rotation Methods

| Rotation | Argument |
|---|---|
| SVD (default) | `rotation=None` |
| Means | `mean_rotation(g1, g2)` |
| Generalised (GMR) | `generalized_rotation(x_var)` |
| Regression (V ~ x) | `regression_rotation(x_var)` |
| Regression (x ~ V) | `regression_rotation_2(x_var)` |
| Custom matrix | `rotation=my_ndarray` |

```python
from pyena import ENA, mean_rotation, generalized_rotation, regression_rotation

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

# Generalised rotation
model_gmr = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
    rotation=generalized_rotation(meta["Condition"])
)

# Regression rotation
import numpy as np
condition_bin = (meta["Condition"] == "FirstGame").astype(float).to_numpy()
model_reg = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
    rotation=regression_rotation(condition_bin)
)
```

---

## Window Options

| Option | Argument |
|---|---|
| Window back | `window_size=4` |
| Window forward | `window_forward=2` |
| Infinite window | `window_size=sys.maxsize` |
| Binary co-occurrence | `binary=True` |
| Weighted co-occurrence | `binary=False` |

---

## Further Reading

- [ENA resources page](https://www.epistemicnetwork.org/resources/)
- [Epistemic Analytics](https://www.epistemicnetwork.org/)
