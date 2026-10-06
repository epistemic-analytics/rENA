# qe-ena

Python implementation of Epistemic Network Analysis (ENA) — sister package to [`rENA`](../README.md).
Install it as `qe-ena`; import it as `pyena`.

> Previously published as `pyENA`. The `pyena` project on PyPI is an
> unrelated package — install `qe-ena` from the QE index as shown below.

`pyena` delegates all core math to [`pylibqe`](https://gitlab.com/epistemic-analytics/qe-packages/libqe),
the shared C++ library that also powers rENA.

---

## Installation

`qe-ena` requires `pylibqe`, which is also on the QE package index; other
dependencies (numpy, pandas) come from PyPI.

```bash
uv add qe-ena --index qe-libs=https://qe-libs.org/py/simple/
# or
pip install qe-ena --extra-index-url https://qe-libs.org/py/simple/
```

Development builds from `main` are on a separate index,
`https://qe-libs.org/py/dev/simple/`. See https://qe-libs.org/py/project/qe-ena/.

### Development install

```bash
pip install pylibqe --extra-index-url https://qe-libs.org/py/simple/
pip install -e ".[dev]"   # from python/ directory
```

---

## Quick Start

```python
import pandas as pd
from pyena import ENA

rs = pd.read_csv("../inst/extdata/rs.data.csv")   # rENA's RS.data

CODES = ["Data", "Technical Constraints", "Performance Parameters",
         "Client and Consultant Requests", "Design Reasoning", "Collaboration"]

# Units and conversations as rENA's RS.data examples: units by Condition +
# UserName, conversations by Condition + GroupName.
rs["unit_key"]  = rs["Condition"] + "::" + rs["UserName"]
rs["convo_key"] = rs["Condition"] + "::" + rs["GroupName"]

model = ENA().fit(rs, "unit_key", "convo_key", CODES, window_size=4)
```

---

## Plotting

pyENA models plot with [qeviz](https://qe-libs.org/py/project/qeviz/), the
interactive ENA / ONA network viewer used by rENA (`pip install qeviz
--index-url https://qe-libs.org/py/simple/`). The two conditions compared —
FirstGame − SecondGame, with each group's mean and 95% confidence interval:

```python
import qeviz

p = (qeviz.from_pyena(model, group_col="Condition", title="FirstGame − SecondGame")
       .edges("FirstGame", compare="SecondGame", color_scale="plot", magnify=3)
       .group())
p                              # displays inline in Jupyter
p.export_html("rs-data.html")  # or a self-contained HTML file
```

![FirstGame − SecondGame network subtraction of RS.data with both group means](https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/raw/main/python/docs/pyena-rs-subtraction.png)

Blue edges are stronger in FirstGame, red in SecondGame. `magnify=3` widens
the edges to make a subtraction's small differences readable (the plot says so).
See the [qeviz README](https://qe-libs.org/py/project/qeviz/) for single-group
networks, unit points, and networks or means from your own data.

---

## Accessing Results

```python
model.line_weights_           # normalised adjacency vectors  (n_units × n_connections)
model.row_connection_counts_  # row-level raw adjacency vectors (n_rows × n_connections)
model.points_                 # unit positions in ENA space   (n_units × dims)
model.centroids_              # network centroids             (n_units × dims)
model.rotation_nodes_         # code node positions           (n_codes × dims)
model.connection_counts_      # raw unit adjacency vectors    (n_units × n_connections)
model.unit_labels_            # unit labels in order
model.connection_names_       # e.g. ["Data & Technical Constraints", ...]
model.variance_               # variance explained per dimension (= rENA's model$variance)
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
          .reindex(model.unit_labels_)
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
