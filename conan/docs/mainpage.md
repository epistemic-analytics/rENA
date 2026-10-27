# libena

Header-only C++ layer for Epistemic Network Analysis (ENA) models: rotations,
node positions and window-size estimation. It is built on
[libqe](https://qe-libs.org/conan/docs/libqe/)'s generic numerics and is the
code shared by rENA (R), qe-ena (Python), rena-wasm (JavaScript) and ENA.jl
(Julia). Network accumulation lives in
[libtma](https://qe-libs.org/conan/docs/libtma/).

Everything is in namespace `qe`. Matrices are Armadillo types.

## Install

Add the qe-libs Conan remote and require `libena`. Available versions are
listed on the [registry page](https://qe-libs.org/conan/).

```
conan remote add qe-libs https://gitlab.com/api/v4/projects/22522458/packages/conan
```

```cmake
find_package(libena REQUIRED)
target_link_libraries(app PRIVATE libena::libena)
```

```cpp
#include <armadillo>
#include <libena/libena.hpp>   // libqe and every libena module
```

## Modules

| Header | Contents |
|--------|----------|
| rotation.hpp | SVD (`qe::ena_svd`), means rotation (`qe::means_rotation`), orthogonal SVD, deflation and `qe::complete_rotation` |
| generalized_rotation.hpp | Generalized means rotation with Lasso covariate adjustment (`qe::generalized_means_rotation`) |
| positions.hpp | Node positions for undirected and directed networks (`qe::node_positions`, `qe::directed_node_positions`), `qe::ena_correlation`, and the unit-circle node move |
| ccd.hpp | Cross-covariance decay window-size estimation (`qe::ccd_window`) |
| bind/ | Armadillo conversions for the nanobind, Emscripten and CxxWrap bindings; not included by `libena.hpp` |

Each routine is written to match the numerical output of rENA's R
implementation.

## Source

[rENA on GitLab](https://gitlab.com/epistemic-analytics/qe-packages/rENA) —
the headers are in `inst/include/libena/`, the Conan recipe in `conan/`.
