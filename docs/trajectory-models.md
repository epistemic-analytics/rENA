# ETM-Style Trajectory Curves in rENA

This note describes the newer ETM-style trajectory curve support in rENA. It
does not document rENA's legacy trajectory model types.

## Current Scope

The ETM-style implementation in rENA is currently a plotting-layer feature. It
fits polynomial curves over an existing sequence of projected ETM/ENA state
points. For those curves to be meaningful as ETM trajectories, the projected
points should come from a door-smoothed accumulation.

rENA does not run the door step itself. Use TMA to prepare the accumulation,
including `tma::door_accumulation()`, then model/project that door-smoothed
accumulation before plotting in rENA.

rENA's pipe-friendly `accumulate()` helper can create a TMA accumulation object
for this workflow. The older `ena.accumulate.data()` API is a separate legacy
rENA accumulation path and is not the recommended ETM door workflow.

## Package Boundaries

rENA owns the plotting API. TMA owns the ETM-style trajectory curve wrapper and
delegates numerical kernels to libqe.

The current call path is:

```text
rENA::accumulate() / tma::accumulate()
  -> tma::door_accumulation()
  -> rENA::model() or ona::model()
  -> rENA plotting
  -> internal ETM bridge helpers
  -> tma::tma_fit_poly_curve()
  -> libqe trajectory kernels
```

In rENA, the internal bridge helpers live in `R/etm_trajectory.R`:

| Helper | Role |
|---|---|
| `.fit_etm_poly_curve()` | Converts projected rENA plot coordinates into the shape expected by TMA and calls `tma::tma_fit_poly_curve()`. |
| `.eval_etm_poly_curve()` | Evaluates a fitted ETM-style polynomial curve into x/y coordinates for plotting. |

## Preparing ETM State Points

The door step happens before plotting. In the original ETM workflow, the order
is:

```text
rENA::accumulate() / tma::accumulate()
  -> tma::door_accumulation()
  -> rENA::model() or ona::model()
  -> rENA trajectory plotting
```

Use `tma::door_accumulation()` for the common path where door-smoothed values
should replace the raw co-occurrence values used by modeling/projection.

```r
library(rENA)

accum <- data |>
  accumulate(
    units = c("UserName", "RowID"),
    codes = codes,
    horizon = c("ConversationID"),
    ordered = TRUE,
    tensor = tensor
  )

accum <- tma::door_accumulation(
  accum,
  method = "Lookback",
  unit_col = "UserName",
  time_col = "RowID",
  lookback_size = 20L,
  aggregate = "sum",
  weighting = "equal"
)

set <- model(
  accum,
  center_to_origin = TRUE
)
```

The same workflow can be written with TMA primitives directly:

```r
context_model <- tma::contexts(...)
tensor <- tma::context_tensor(...)

accum <- tma::accumulate(
  context_model = context_model,
  codes = codes,
  tensor = tensor,
  ordered = TRUE
)

accum <- tma::door_accumulation(
  accum,
  method = "Lookback",
  unit_col = "UserName",
  time_col = "RowID",
  lookback_size = 20L,
  aggregate = "sum",
  weighting = "equal"
)

set <- model(accum, center_to_origin = TRUE)
```

Use `tma::door()` and `tma::replace_door()` separately when you want to inspect
or compare the intermediate `door_*` columns before replacing the accumulation
values.

## Static Curves

Use `ena.plot.trajectory()` when you already have an `ENAplot`, point
coordinates, and a grouping vector. Setting `smooth = "poly"` enables the
ETM-style polynomial curve path. The example below assumes `set` was built from
a door-smoothed accumulation.

```r
library(rENA)

p <- ena.plot(set)

p <- ena.plot.trajectory(
  enaplot = p,
  points = set$points,
  by = set$meta.data$Condition,
  smooth = "poly",
  poly.max.degree = 3
)

p
```

## Animated Curves

Use `ena.plot.movie()` when you already have point coordinates, a grouping
vector, and a time/turn vector. Setting `smooth = "poly"` enables the same
ETM-style polynomial curve path used by `ena.plot.trajectory()`. Again, this is
meaningful as ETM only when the input points came from door-smoothed state rows.

```r
movie <- ena.plot.movie(
  enaplot = ena.plot(set),
  points = set$points,
  by = set$meta.data$Condition,
  time = seq_len(nrow(set$points)),
  smooth = "poly",
  poly.max.degree = 3
)

movie
```

## What This Does Not Do Yet

The ETM-style curve layer does not currently:

- Create ETM-specific accumulations in rENA.
- Replace the ENA accumulation/modeling pipeline.
- Apply door smoothing before projection inside rENA.
- Expose ETM derivative, critical-point, distance, or following analysis through
  rENA.

Those behaviors belong in TMA, ONA, or in a higher-level workflow that prepares
door-smoothed model outputs before rENA plots them.
