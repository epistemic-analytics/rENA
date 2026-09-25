# @qe-libs/rena-wasm

JavaScript/WebAssembly ENA pipeline — thin orchestration layer over
[`@qe-libs/libqe-wasm`](../../libqe/wasm/README.md).

Handles data parsing, unit/conversation grouping, and the full
accumulate → normalize → center → rotate → project → node-positions pipeline.
All math is delegated to the libqe WASM module; no C++ compilation required here.

---

## Installation

```bash
npm install @qe-libs/rena-wasm
```

---

## Quick Start

```js
import loadENA from '@qe-libs/rena-wasm';

const ena = await loadENA();

const model = ena.fit(rows, {
  codes:         ['Data', 'Technical.Constraints', 'Performance.Parameters'],
  units:         ['UserName', 'Condition'],
  conversations: ['Condition', 'GroupName'],
  window:        4,
  dims:          2,
});

model.model.centroids  // Float64Array  nUnits × dims
model.lineWeights      // Float64Array  nUnits × nConnections (normed)
model.connectionCounts // Float64Array  nUnits × nConnections (unit counts, before normalisation)
model.rowConnectionCounts // Float64Array nRows × nConnections (each row's counts after binarize / weight; rows sum to connectionCounts)
model.rotation.nodes   // Float64Array  nCodes × dims
model.connectionNames  // ['Data & Technical.Constraints', ...]
model.model.unitLabels // ['UserName1_ConditionA', ...]
model.rotation.columnNames // ['SVD1', 'SVD2']

// Per-unit helpers
model.centroid('Alice_A')  // number[]  length = dims
model.network('Alice_A')   // number[]  length = nConnections
```

---

## Rotation Methods

| Method | `rotation` option | Extra options |
|---|---|---|
| SVD (default) | `'svd'` | — |
| Means | `'mean'` | `groupA: [unitIdx, ...]`, `groupB: [unitIdx, ...]` |

```js
// Means rotation — groupA/groupB are unit indices (position in unitLabels)
const model = ena.fit(rows, {
  codes, units, conversations,
  rotation: 'mean',
  groupA: [0, 1, 2],
  groupB: [3, 4, 5],
});
```

---

## Weight Models

`weightModel` (= R's `weight.by` / tma's `weight_by`) is applied to each line's
co-occurrence counts **before** they are summed into the unit network, by
libqe's shared `finalize_row_connections` kernel — the same stage and results
as rENA's `ena.accumulate.data()` and `tma::accumulate()`.

| `weightModel` | Per line |
|---|---|
| — (default) | binary: each positive count becomes 1 (`binary: false` keeps raw counts) |
| `'product'` | the raw, non-binarized counts |
| `'sqrt'` | square root of each line's count |
| `'log'` (alias `'log1p'`) | `log(1 + x)` of each line's count |

For ordered (directed) networks the weight is applied to each directed cell,
and the default keeps the raw directed counts. `weightModel` works in `fit()`,
`accumulate()` and `tuneWindowSize()`.

```js
const model = ena.fit(rows, { codes, units, conversations, window: 4, weightModel: 'sqrt' });
```

---

## Reduced-Code Search (PRIA)

`pria()` finds the largest set of codes (up to `removeNum`, never leaving
fewer than 3) whose removal keeps the model within `threshold` of the full
model — the same search, gates and tie-break as R's `PRIA::pria()`. It takes
the same options as `fit()` (rotation, `weightModel`, `tensor`, `codeMask`,
…), so it scores the model you display.

```js
const { removed, k, variance } = ena.pria(rows, {
  codes, units, conversations, window: 4,
  rotation: 'mean', groupA, groupB,
  removeNum: 3, threshold: 0.95,
});
// removed  → code names to drop (most codes first, then highest dim-1 variance)
// variance → dim-1 share of variance in the chosen reduced model
```

---

## Accumulation Only

Returns raw (un-normalised) network vectors without running the full pipeline.

```js
const { connectionCounts, rowConnectionCounts, unitLabels, connectionNames, nUnits, nConnections } =
  ena.accumulate(rows, { codes, units, conversations, window: 4 });
```

---

## Advanced: Context Tensor Accumulation

Context tensors give per-factor-combination control over window sizes and
weights — the JS equivalent of `tma::accumulate_contexts()` with HOO rules.

The tensor is a multi-dimensional array whose last axis is always size 2
(index 0 = weight, index 1 = window). Earlier axes correspond to factor
columns in the data.

```js
// Example: sender role (T=Teacher, S=Student) controls the window size.
// dims = [nRoleValues, 2]  →  Teacher uses window=4, Student uses window=2.
const model = ena.fit(rows, {
  codes, units, conversations,
  ordered: true,   // directed (n² connections); also works without a tensor.
                   // Ordered models follow ona::model(): zero-network units are
                   // left out of the centring mean but shifted by it, nodes use
                   // directed positions, and points/nodes are centred on the origin.
                   // connectionNames / rotation.adjacencyKey list all n² directed
                   // connections as R names them: column j*n + i is
                   // "codes[i] & codes[j]", ground codes[i] → response codes[j].
  tensor: {
    dims:         [2, 2],   // [nRoleValues=2, weight/window=2]
    dimsSender:   [0],      // axis 0 is a sender factor
    dimsReceiver: [],
    dimsMode:     [],
    factors:      ['Role'], // column in the data
    // Optional: explicit value → index mapping.  Inferred automatically if omitted.
    factorLevels: { Role: { 'Teacher': 0, 'Student': 1 } },
    // Flat column-major: [weight_T, weight_S, window_T, window_S]
    data: Float64Array.of(1, 1, 4, 2),
  },
});
```

### Tensor layout

The `data` array is **column-major** with shape `dims`. The last axis
selects weight (`0`) or window (`1`). For `dims = [nA, nB, 2]`:

```
data[a + nA*b + nA*nB*0]  →  weight for factor combination (a, b)
data[a + nA*b + nA*nB*1]  →  window for factor combination (a, b)
```

### Factor axis roles

| Option | Meaning |
|---|---|
| `dimsSender` | These axes use the *ground* row's factor values when looking up the window |
| `dimsReceiver` | These axes use the *response* row's factor values (overrides ground) |
| `dimsMode` | These axes use a shared mode value |

### `defaultTensor` helper

Express simple windowed accumulation as a tensor (IS_DEFAULT path):

```js
import { defaultTensor } from '@qe-libs/rena-wasm/src/tensor.js';

const tensor = defaultTensor(4);        // window=4, weight=1
const tensor = defaultTensor(4, 0.5);  // window=4, weight=0.5
```

---

## Input Format

`rows` is an array of plain objects — one per utterance/event.

```js
const rows = [
  { UserName: 'Alice', Condition: 'A', GroupName: 'G1', Role: 'Teacher', Data: 1, Reasoning: 0 },
  ...
];
```

Code column values should be numeric (0/1 for binary codes). Factor column
values can be any string or number — they are mapped to 0-based indices
automatically unless `factorLevels` is provided explicitly.

---

## Testing

```bash
npm install
npm test
```

Tests cover the simple windowed pipeline (`test/ena.test.js`) and the
context-tensor path (`test/tensor.test.js`).
