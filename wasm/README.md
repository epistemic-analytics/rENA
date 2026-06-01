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

model.centroids        // Float64Array  nUnits × dims
model.networks         // Float64Array  nUnits × nConnections (normed)
model.positions        // Float64Array  nCodes × dims
model.connectionNames  // ['Data & Technical.Constraints', ...]
model.unitLabels       // ['UserName1_ConditionA', ...]
model.columnNames      // ['SVD1', 'SVD2']
```

## Rotation Methods

| Method | `rotation` option | Extra options |
|---|---|---|
| SVD (default) | `'svd'` | — |
| Means | `'mean'` | `groupA: [unitIdx, ...]`, `groupB: [unitIdx, ...]` |

## Accumulation Only

```js
const { networks, unitLabels, connectionNames } = ena.accumulate(rows, {
  codes, units, conversations, window: 4,
});
```

## Input Format

`rows` is an array of plain objects — one per utterance/event. Column values
for code columns should be numeric (0/1 for binary codes).

```js
const rows = [
  { UserName: 'Alice', Condition: 'A', GroupName: 'G1', Data: 1, Reasoning: 0 },
  ...
];
```

## Testing

```bash
npm test   # requires @qe-libs/libqe-wasm to be installed (npm install)
```
