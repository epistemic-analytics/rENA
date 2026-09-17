/**
 * @qe-libs/rena-wasm
 *
 * JavaScript/WebAssembly ENA pipeline.
 * Thin orchestration layer over @qe-libs/libqe-wasm — handles data parsing,
 * unit/conversation grouping, and the full accumulate→normalize→center→
 * rotate→project→node-positions pipeline.
 *
 * Output structure mirrors R's ena.set object (without R-specific S3 class
 * attributes and without metadata columns prepended to every matrix).
 * Metadata lives in metaData / model.metaData instead.
 *
 * Top-level fields (= R's set$...):
 *   connectionCounts  Float64Array  (nUnits × nConnections) — raw accumulation
 *   rowConnectionCounts Float64Array (nRows × nConnections) — per-row raw accumulation
 *   lineWeights       Float64Array  (nUnits × nConnections) — sphere-normed
 *   points            Float64Array  (nUnits × dims)         — projected positions
 *   rotationMatrix    Float64Array  (nConnections × dims)   — rotation vectors
 *   metaData          Object[]      one object per unit, non-code/unit/convo cols
 *   connectionNames   string[]
 *   columnClasses     Object        matrix name → R column class string
 *   nUnits            number
 *   nConnections      number
 *   dims              number
 *
 * model sub-object (= R's set$model$...):
 *   model.rowConnectionCounts Float64Array (nRows × nConnections) — per-row raw accumulation
 *   model.centroids           Float64Array  (nUnits × dims) — LWS centroids
 *   model.variance            number[]      variance explained per dim
 *   model.unitLabels          string[]
 *   model.pointsForProjection Float64Array  (nUnits × nConnections) — centered normed
 *
 * rotation sub-object (= R's set$rotation$...):
 *   rotation.rotationMatrix  Float64Array  same reference as top-level rotationMatrix
 *   rotation.nodes           Float64Array  (nCodes × dims) — code positions
 *   rotation.columnNames     string[]      axis labels e.g. ['SVD1','SVD2']
 *   rotation.eigenvalues     number[]
 *   rotation.centerVec       Float64Array  (nConnections) — centering vector
 *   rotation.codes           string[]
 *   rotation.adjacencyKey    string[][]    [[codeA,codeB], ...] per connection
 */

import loadLibQE from '@qe-libs/libqe-wasm';
import { parseData } from './data.js';
import {
    accumulate, accumulateWithRows, sphereNorm, center,
    rotateSVD, rotateMeans, rotateGeneralized,
    project, nodePositions, spaceDistCorr,
} from './pipeline.js';
import { accumulateTensor, defaultTensor } from './tensor.js';

// Heuristic model-parameter detection (units / conversations / codes).
// Pure JS — re-exported synchronously so callers don't need to load WASM.
export { detectParams, isBinary, scoreUnit, scoreConvo } from './detect.js';

// ── helpers ───────────────────────────────────────────────────────────────────

/**
 * Compute per-dimension variance explained from projected unit positions.
 * Matches R: diagonal(var(points)) / sum(diagonal(var(points)))
 *
 * @param {Float64Array} points  nUnits × dims, row-major
 * @param {number}       nUnits
 * @param {number}       dims
 * @returns {number[]}  length dims, sums to 1
 */
function computeVariance(points, nUnits, dims) {
    if (nUnits < 2) return Array.from({ length: dims }, () => 1 / dims);

    // Column means
    const means = new Float64Array(dims);
    for (let u = 0; u < nUnits; u++)
        for (let d = 0; d < dims; d++)
            means[d] += points[u * dims + d];
    for (let d = 0; d < dims; d++) means[d] /= nUnits;

    // Sample variance (n-1 denominator, matching R's var())
    const variances = new Float64Array(dims);
    for (let u = 0; u < nUnits; u++)
        for (let d = 0; d < dims; d++) {
            const diff = points[u * dims + d] - means[d];
            variances[d] += diff * diff;
        }
    for (let d = 0; d < dims; d++) variances[d] /= (nUnits - 1);

    const total = Array.from(variances).reduce((a, b) => a + b, 0);
    if (total === 0) return Array.from({ length: dims }, () => 1 / dims);
    return Array.from(variances).map(v => v / total);
}

/**
 * Build the adjacency key — list of [codeA, codeB] pairs for each connection.
 * Matches R's enadata$adjacency.matrix (column-major upper triangle order).
 *
 * @param {string[]} codes
 * @returns {string[][]}  length nConnections, each entry is [codeI, codeJ]
 */
function buildAdjacencyKey(codes) {
    const key = [];
    for (let j = 1; j < codes.length; j++)
        for (let i = 0; i < j; i++)
            key.push([codes[i], codes[j]]);
    return key;
}

// ── ENA result object ─────────────────────────────────────────────────────────

class ENAModel {
    constructor(opts) {
        // ── top-level fields (= R's set$...) ────────────────────────────────
        this.connectionCounts = opts.connectionCounts;  // raw networks
        this.rowConnectionCounts = opts.rowConnectionCounts;
        this.lineWeights      = opts.lineWeights;       // sphere-normed networks
        this.points           = opts.points;            // projected unit positions
        this.rotationMatrix   = opts.rotationMatrix;    // n_connections × dims
        this.metaData         = opts.metaData;          // array of unit metadata objects
        this.connectionNames  = opts.connectionNames;
        this.nUnits           = opts.nUnits;
        this.nConnections     = opts.nConnections;
        this.dims             = opts.dims;

        // ── model sub-object (= R's set$model$...) ───────────────────────────
        this.model = {
            rowConnectionCounts: opts.rowConnectionCounts,
            centroids:           opts.centroids,           // LWS positions
            variance:            opts.variance,            // variance explained
            unitLabels:          opts.unitLabels,
            pointsForProjection: opts.pointsForProjection, // centered normed networks
        };

        // ── rotation sub-object (= R's set$rotation$...) ────────────────────
        this.rotation = {
            rotationMatrix: opts.rotationMatrix,  // same reference as top-level
            nodes:          opts.nodes,           // code positions
            columnNames:    opts.columnNames,     // axis labels ['SVD1','SVD2']
            eigenvalues:    opts.eigenvalues,
            centerVec:      opts.centerVec,
            codes:          opts.codes,
            adjacencyKey:   opts.adjacencyKey,
        };

        // ── column class annotations (mirrors R's S3 class tags) ─────────────
        this.columnClasses = {
            connectionCounts:    'ena.co.occurrence',
            lineWeights:         'ena.co.occurrence',
            points:              'ena.dimension',
            pointsForProjection: 'ena.co.occurrence',
            rotationMatrix:      'ena.dimension',
            nodes:               'ena.dimension',
        };
    }

    /**
     * Projected position for a single unit (= R's set$points[unit,]).
     * @param {string} unitLabel
     * @returns {number[]}
     */
    point(unitLabel) {
        const idx = this.model.unitLabels.indexOf(unitLabel);
        if (idx < 0) throw new Error(`Unknown unit: ${unitLabel}`);
        return Array.from(this.points.subarray(idx * this.dims, (idx + 1) * this.dims));
    }

    /**
     * LWS centroid for a single unit (= R's set$model$centroids[unit,]).
     * @param {string} unitLabel
     * @returns {number[]}
     */
    centroid(unitLabel) {
        const idx = this.model.unitLabels.indexOf(unitLabel);
        if (idx < 0) throw new Error(`Unknown unit: ${unitLabel}`);
        if (!this.model.centroids) throw new Error('LWS centroids not available from libqe');
        return Array.from(this.model.centroids.subarray(idx * this.dims, (idx + 1) * this.dims));
    }

    /**
     * Normed network vector for a single unit (= R's set$line.weights[unit,]).
     * @param {string} unitLabel
     * @returns {number[]}
     */
    network(unitLabel) {
        const idx = this.model.unitLabels.indexOf(unitLabel);
        if (idx < 0) throw new Error(`Unknown unit: ${unitLabel}`);
        return Array.from(this.lineWeights.subarray(
            idx * this.nConnections, (idx + 1) * this.nConnections
        ));
    }
}

// ── weight models (= R's `weight.by`) ────────────────────────────────────────

/**
 * Map a weight-model name to its element-wise transform, matching the webtool's
 * server.js mapping to R weight.by functions:
 *   'sqrt'    → Math.sqrt          (R "sqrt")
 *   'log'     → Math.log1p         (R "log1p", i.e. log(x+1); guards log(0))
 *   'product' → identity           (raw non-binary counts; R's "product" string
 *                                    is not a function, so no transform)
 * A falsy value or 'binary' returns null (binary accumulation, no transform).
 * @param {string|false|undefined} name
 * @returns {((x:number)=>number)|null}
 */
function weightModelTransform(name) {
    switch (name) {
        case 'sqrt':    return Math.sqrt;
        case 'log':     return Math.log1p;
        case 'product': return (x) => x;
        default:        return null;   // binary / off / unknown
    }
}

// ── shared pipeline (post-accumulation) ──────────────────────────────────────

function runPipeline(qe, rawNetworks, nUnits, nConnections, codes, unitLabels,
                     metaData, rotMethod, groupA, groupB, dims, gParams,
                     rowConnectionCounts = null) {
    const connectionNames = qe.connection_names(codes);

    // Sphere norm → lineWeights (= R's set$line.weights)
    const lineWeights = sphereNorm(qe, rawNetworks, nUnits, nConnections);

    // Center → pointsForProjection (= R's model$points.for.projection)
    //          centerVec             (= R's rotation$center.vec)
    const { centered: pointsForProjection, centerVec } =
        center(qe, lineWeights, nUnits, nConnections);

    // Rotate
    let rot;
    if (rotMethod === 'generalized') {
        if (!gParams) throw new Error(
            'opts.gParams is required for generalized (GMR) rotation'
        );
        rot = rotateGeneralized(qe, pointsForProjection, nUnits, nConnections, gParams);
    } else if (rotMethod === 'mean') {
        if (!groupA || !groupB) throw new Error(
            'opts.groupA and opts.groupB are required for means rotation'
        );
        rot = rotateMeans(qe, pointsForProjection, nUnits, nConnections, groupA, groupB);
    } else {
        rot = rotateSVD(qe, pointsForProjection, nUnits, nConnections);
    }

    // Truncate rotation matrix to dims columns (= R's set$rotation.matrix)
    const rotationMatrix = new Float64Array(rot.rotRows * dims);
    for (let r = 0; r < rot.rotRows; r++)
        for (let d = 0; d < dims; d++)
            rotationMatrix[r * dims + d] = rot.rotation[r * rot.rotCols + d];

    const columnNames = rot.columnNames.slice(0, dims);

    // Project → points (= R's set$points)
    const points = project(
        pointsForProjection, nUnits, nConnections,
        rot.rotation, rot.rotRows, rot.rotCols, dims
    );

    // Node positions (LWS) → rotation.nodes + model.centroids
    // Matches rENA's lws.positions.sq, which regresses the projected points onto
    // the SPHERE-normed line weights (enaset$line.weights) — not the centered
    // networks.  Verified node-for-node against R rENA on rs.data.new.csv.
    const { nodes, centroids } = nodePositions(
        qe, lineWeights, nUnits, nConnections, points, dims
    );

    // Variance explained (= R's model$variance)
    const variance = computeVariance(points, nUnits, dims);

    // Adjacency key (= R's rotation$adjacency.key)
    const adjacencyKey = buildAdjacencyKey(codes);

    return new ENAModel({
        // top-level
        connectionCounts:     rawNetworks,
        rowConnectionCounts,
        lineWeights,
        points,
        rotationMatrix,
        metaData,
        connectionNames,
        nUnits,
        nConnections,
        dims,
        // model sub
        centroids,
        variance,
        unitLabels,
        pointsForProjection,
        // rotation sub
        nodes,
        columnNames,
        eigenvalues:  rot.eigenvalues,
        centerVec,
        codes,
        adjacencyKey,
    });
}

// ── main factory ─────────────────────────────────────────────────────────────

/**
 * Load the ENA module.  Returns an object with `fit()` and `accumulate()`.
 *
 * @returns {Promise<{fit: Function, accumulate: Function}>}
 */
export default async function loadENA() {
    const qe = await loadLibQE();

    const api = {
        /**
         * Run the full ENA pipeline.
         *
         * @param {Object[]} rows  - Tabular data (array of row objects)
         * @param {object}   opts
         * @param {string[]} opts.codes            - Code column names
         * @param {string[]} opts.units            - Unit identifier column(s)
         * @param {string[]} opts.conversations    - Conversation identifier column(s)
         * @param {number}   [opts.window=4]       - Backward window (simple path; ignored when tensor provided)
         * @param {boolean}  [opts.binary=true]    - Binarise co-occurrences (simple path only)
         * @param {boolean}  [opts.ordered=false]  - Directed networks (tensor path only)
         * @param {object}   [opts.tensor]         - Context tensor definition
         * @param {string}   [opts.rotation='svd'] - 'svd', 'mean', or 'generalized'
         * @param {number[]} [opts.groupA]         - Unit indices for means rotation group A
         * @param {number[]} [opts.groupB]         - Unit indices for means rotation group B
         * @param {object}   [opts.gParams]        - Pre-built GMR parameters for 'generalized' rotation
         * @param {number}   [opts.dims=2]         - Number of dimensions to return
         *
         * @returns {ENAModel}
         */
        fit(rows, opts = {}) {
            const {
                codes,
                units,
                conversations,
                window:   windowSize = 4,
                binary               = true,
                ordered              = false,
                tensor:   tensorDef,
                rotation: rotMethod  = 'svd',
                groupA,
                groupB,
                gParams,
                dims                 = 2,
                codeMask,
                weightModel,
            } = opts;

            if (!codes?.length)         throw new Error('opts.codes is required');
            if (!units?.length)         throw new Error('opts.units is required');
            if (!conversations?.length) throw new Error('opts.conversations is required');

            // Weight model = R's `weight.by`. R applies it per LINE (each row's
            // windowed co-occurrence counts) BEFORE summing per unit, mirroring
            // accumulate.data.R (lapply(.SD, weight.by) over the per-line
            // co-occurrence table, then per-unit aggregation). Because
            // sqrt(Σ) ≠ Σsqrt, the transform must be applied to the per-row
            // counts and then re-summed — not to the already-unit-summed network.
            // A non-binary weight model forces non-binary accumulation. `product`
            // keeps the raw counts (identity), matching R where the "product"
            // string is not a function and so falls through untransformed.
            // Applied on BOTH paths, at the same stage, so a weight model means
            // the same thing whether accumulation is windowed or transmodal:
            // windowed re-aggregates the per-row co-occurrences below; the
            // tensor path applies the transform inside accumulateTensor.
            const weightFn = weightModelTransform(weightModel);
            const effBinary = weightFn ? false : binary;

            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups, metaData } =
                parseData(rows, codes, units, conversations);

            let rawNetworks, rowConnectionCounts = null, nConnections;

            if (tensorDef) {
                rawNetworks  = accumulateTensor(
                    qe, rows, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, tensorDef, ordered, effBinary, weightFn
                );
                nConnections = ordered ? nCodes * nCodes : qe.choose_two(nCodes);
            } else {
                const accumulated = accumulateWithRows(
                    qe, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, windowSize, effBinary
                );
                rawNetworks = accumulated.networks;
                rowConnectionCounts = accumulated.rowConnectionCounts;
                nConnections = qe.choose_two(nCodes);

                // Line-level weight transform: weight each per-row count, then
                // re-aggregate per unit (matches R's weight.by ordering).
                if (weightFn) {
                    rawNetworks.fill(0);
                    for (let r = 0; r < nRows; r++) {
                        const unit = unitOf[r];
                        const rowOff = r * nConnections;
                        const unitOff = unit * nConnections;
                        for (let c = 0; c < nConnections; c++) {
                            const w = weightFn(rowConnectionCounts[rowOff + c]);
                            rowConnectionCounts[rowOff + c] = w;
                            rawNetworks[unitOff + c] += w;
                        }
                    }
                }
            }

            // Apply code masking by zeroing out the masked connection columns across all units
            if (codeMask && codeMask.length === codes.length) {
                console.log('[rena-wasm] Applying code mask to raw networks...');
                if (ordered) {
                    for (let j = 0; j < codes.length; j++) {
                        for (let i = 0; i < codes.length; i++) {
                            if (codeMask[j] && codeMask[j][i] === 0) {
                                const k = i * codes.length + j;
                                for (let u = 0; u < nUnits; u++) {
                                    rawNetworks[u * nConnections + k] = 0;
                                }
                            }
                        }
                    }
                } else {
                    let k = 0;
                    for (let col = 1; col < codes.length; col++) {
                        for (let row = 0; row < col; row++) {
                            if ((codeMask[row] && codeMask[row][col] === 0) || (codeMask[col] && codeMask[col][row] === 0)) {
                                for (let u = 0; u < nUnits; u++) {
                                    rawNetworks[u * nConnections + k] = 0;
                                }
                            }
                            k++;
                        }
                    }
                }
            }

            return runPipeline(qe, rawNetworks, nUnits, nConnections, codes,
                               unitLabels, metaData, rotMethod, groupA, groupB,
                               dims, gParams, rowConnectionCounts);
        },

        /**
         * Run only the accumulation step (= R's ena.accumulate.data()).
         * Returns raw (un-normalised) network vectors.
         *
         * @param {Object[]} rows
         * @param {object}   opts  - codes, units, conversations, window, binary, ordered, tensor
         * @returns {{
         *   connectionCounts: Float64Array,
         *   rowConnectionCounts: Float64Array | null,
         *   unitLabels:       string[],
         *   connectionNames:  string[],
         *   metaData:         Object[],
         *   nUnits:           number,
         *   nConnections:     number,
         *   _call:            object,   // args used to build this accumulation (for tuneWindowSize)
         * }}
         */
        accumulate(rows, opts = {}) {
            const {
                codes, units, conversations,
                window:  windowSize = 4,
                binary               = true,
                ordered              = false,
                tensor:  tensorDef,
                codeMask,
            } = opts;

            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups, metaData } =
                parseData(rows, codes, units, conversations);

            let networks, rowConnectionCounts = null, nConnections;

            if (tensorDef) {
                networks     = accumulateTensor(
                    qe, rows, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, tensorDef, ordered, binary
                );
                nConnections = ordered ? nCodes * nCodes : qe.choose_two(nCodes);
            } else {
                const accumulated = accumulateWithRows(
                    qe, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, windowSize, binary
                );
                networks = accumulated.networks;
                rowConnectionCounts = accumulated.rowConnectionCounts;
                nConnections = qe.choose_two(nCodes);
            }

            // Apply code masking by zeroing out the masked connection columns across all units
            if (codeMask && codeMask.length === codes.length) {
                console.log('[rena-wasm] Applying code mask to accumulated networks...');
                if (ordered) {
                    for (let j = 0; j < codes.length; j++) {
                        for (let i = 0; i < codes.length; i++) {
                            if (codeMask[j] && codeMask[j][i] === 0) {
                                const k = i * codes.length + j;
                                for (let u = 0; u < nUnits; u++) {
                                    networks[u * nConnections + k] = 0;
                                }
                            }
                        }
                    }
                } else {
                    let k = 0;
                    for (let col = 1; col < codes.length; col++) {
                        for (let row = 0; row < col; row++) {
                            if ((codeMask[row] && codeMask[row][col] === 0) || (codeMask[col] && codeMask[col][row] === 0)) {
                                for (let u = 0; u < nUnits; u++) {
                                    networks[u * nConnections + k] = 0;
                                }
                            }
                            k++;
                        }
                    }
                }
            }

            const connectionNames = qe.connection_names(codes);
            return {
                connectionCounts: networks, rowConnectionCounts, unitLabels, connectionNames,
                metaData, nUnits, nConnections,
                // Retained so tuneWindowSize() can rebuild at other window sizes
                // (= R's ENAAccumulation$`_function.call`).
                _call: { rows, codes, units, conversations,
                         window: windowSize, binary, ordered, tensor: tensorDef },
            };
        },

        /**
         * Tune the stanza window size (= R's ena.tune.window.size).
         *
         * Rebuilds the accumulation and fits a default SVD model for every
         * window from `minSize` to `maxSize`, correlates the unit-distance
         * geometry of adjacent window sizes via spaceDistCorr, and selects the
         * smallest window whose adjacent correlation reaches
         * `cutoff * max(correlation)`. Mirrors R by returning a fresh
         * accumulation rebuilt at the selected window size.
         *
         * @param {object} accum  - an accumulation returned by accumulate()
         * @param {object} [opts]
         * @param {number} [opts.minSize=1]
         * @param {number} [opts.maxSize=20]
         * @param {number} [opts.cutoff=0.95]
         * @returns {object}  accumulation rebuilt at the selected window
         *                    (selected size available as result._call.window)
         */
        tuneWindowSize(accum, opts = {}) {
            const { minSize = 1, maxSize = 20, cutoff = 0.95 } = opts;
            const call = accum && accum._call;
            if (!call) throw new Error(
                'accum has no stored _call; build it with accumulate() to enable tuning.'
            );
            if (call.tensor) throw new Error(
                'window-size tuning is only supported for the simple (window) accumulation path.'
            );

            const windowRange = [];
            for (let w = minSize; w <= maxSize; w++) windowRange.push(w);
            if (windowRange.length < 2) throw new Error(
                'maxSize must be greater than minSize to compare windows.'
            );

            const { rows, codes, units, conversations, binary } = call;

            // Parse once; only the window size changes between iterations.
            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups, metaData } =
                parseData(rows, codes, units, conversations);
            const nConnections = qe.choose_two(nCodes);

            // 1. Rebuild + fit at each window, collecting unit points.
            const dims = 2;
            const allPoints = [];
            for (const w of windowRange) {
                const raw = accumulate(
                    qe, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, w, binary
                );
                const model = runPipeline(
                    qe, raw, nUnits, nConnections, codes,
                    unitLabels, metaData, 'svd', undefined, undefined, dims
                );
                allPoints.push(model.points);
            }

            // 2. Adjacent-window distance-space correlations.
            const nSteps = windowRange.length - 1;
            const corr = new Array(nSteps);
            for (let i = 0; i < nSteps; i++) {
                corr[i] = spaceDistCorr(allPoints[i], allPoints[i + 1], nUnits, dims);
            }

            // 3. Smallest window crossing cutoff * max correlation.
            const finite = corr.filter(v => !Number.isNaN(v));
            const maxCorr = finite.length ? Math.max(...finite) : NaN;
            const threshold = cutoff * maxCorr;
            let bestIdx = corr.findIndex(v => v >= threshold);
            if (bestIdx < 0) bestIdx = 0;
            const bestWindow = windowRange[bestIdx];

            // 4. Rebuild the accumulation at the selected window size.
            return api.accumulate(rows, {
                codes, units, conversations, window: bestWindow, binary,
            });
        },

        /**
         * Estimate the moving-window size via Cross-Covariance Decay (CCD)
         * (= R's ena.ccd). Computes the noise-corrected cross-covariance decay
         * curves over lags and returns the half-life lag as the window size.
         *
         * Unlike tuneWindowSize (which rebuilds+fits a full SVD model at each
         * window), CCD runs directly on the raw code matrix per conversation —
         * no accumulation/rotation — via the shared libqe kernel.
         *
         * @param {Object[]} rows
         * @param {object}   opts
         * @param {string[]} opts.codes            - Code column names
         * @param {string[]} opts.conversations    - Conversation identifier column(s)
         * @param {number}   [opts.maxWindow=20]   - Maximum lag to evaluate
         * @param {number}   [opts.minOverlap=10]  - Minimum overlapping rows per conversation at a lag
         * @returns {{
         *   window_size:          number,
         *   peak_lag:             number,
         *   lag:                  number[],
         *   frob:                 number[],
         *   frob_sq_unbiased:     number[],
         *   frob_unbiased_signed: number[],
         *   total_weight:         number[],
         * }}
         */
        ccd(rows, opts = {}) {
            const { codes, conversations, maxWindow = 20, minOverlap = 10 } = opts;
            if (!codes?.length)         throw new Error('opts.codes is required');
            if (!conversations?.length) throw new Error('opts.conversations is required');

            // Units are irrelevant to CCD; reuse conversations as a placeholder
            // so parseData can build codeMatrix + convoGroups.
            const { codeMatrix, nRows, nCodes, convoGroups } =
                parseData(rows, codes, conversations, conversations);

            // Flatten conversation row groups into (sizes, indices) for the kernel.
            const groupSizes = [];
            const rowIndices = [];
            for (const rowIdxs of convoGroups.values()) {
                groupSizes.push(rowIdxs.length);
                for (const ri of rowIdxs) rowIndices.push(ri);
            }

            return qe.ccd_window(
                codeMatrix, nRows, nCodes, groupSizes, rowIndices, maxWindow, minOverlap
            );
        },

        /**
         * Convenience wrapper returning only the estimated window size
         * (= R's ena.ccd.window).
         *
         * @param {Object[]} rows
         * @param {object}   opts  - see ccd()
         * @returns {number}  estimated window size
         */
        ccdWindow(rows, opts = {}) {
            return api.ccd(rows, opts).window_size;
        },

        /**
         * Per-dimension t-based confidence intervals around the column means.
         * Matches R's conf.ints / libqe::mean_ci.
         *
         * @param {Float64Array} points     nUnits × dims, row-major
         * @param {number}       nUnits
         * @param {number}       dims
         * @param {number}       [confLevel=0.95]
         * @returns {{ data: Float64Array, rows: number, cols: number }}
         *   rows=dims, cols=3 — columns: mean, lower CI, upper CI
         */
        confInts(points, nUnits, dims, confLevel = 0.95) {
            return qe.mean_ci(points, nUnits, dims, confLevel);
        },

        /**
         * Per-dimension Tukey-fence outlier intervals (Q1-k*IQR, Q3+k*IQR).
         * Matches R's outlier.ints / libqe::outlier_ci.
         *
         * @param {Float64Array} points     nUnits × dims, row-major
         * @param {number}       nUnits
         * @param {number}       dims
         * @param {number}       [iqrFactor=1.5]
         * @returns {{ data: Float64Array, rows: number, cols: number }}
         *   rows=dims, cols=2 — columns: lower fence, upper fence
         */
        outlierInts(points, nUnits, dims, iqrFactor = 1.5) {
            return qe.outlier_ci(points, nUnits, dims, iqrFactor);
        },

        /**
         * Per-dimension parametric and non-parametric two-group statistics.
         * Matches R's set$tests / libqe::group_stats.
         *
         * @param {Float64Array} g1Points  group 1 points, nG1 × dims, row-major
         * @param {number}       nG1
         * @param {Float64Array} g2Points  group 2 points, nG2 × dims, row-major
         * @param {number}       nG2
         * @param {number}       dims
         * @returns {{ n1, n2, t, df, pvalue_t, cohens_d, means, sds,
         *             U, pvalue_u, effect_r, medians }}
         */
        compareGroups(g1Points, nG1, g2Points, nG2, dims) {
            return qe.group_stats(g1Points, nG1, dims, g2Points, nG2, dims);
        },

        /**
         * PRIA — find the largest set of codes (up to removeNum) that can be
         * removed while keeping the model's goodness-of-fit within `threshold`
         * of the full model.  Brute-force subset search matching R
         * PRIA::pria(): for k = 1..removeNum, over every k-subset of codes,
         * build the reduced model (fit with a codeMask that drops every
         * connection touching a removed code), gate on
         * min_d(gof_reduced[d] / gof_full[d]) >= threshold where gof is the
         * per-dimension ena_correlation(points, centroids), and keep the subset
         * with the MOST codes removed, then the highest reduced dim-1 variance.
         *
         * @returns {{ removed: string[], removedIndices: number[], k: number,
         *             variance: (number|null) }}
         */
        pria(rows, opts = {}) {
            const {
                codes, units, conversations,
                window: windowSize = 4, binary = true, ordered = false,
                rotation = 'svd', dims = 2, gParams, groupA, groupB,
                removeNum = 3, threshold = 0.95,
            } = opts;
            if (!codes?.length)         throw new Error('opts.codes is required');
            if (!units?.length)         throw new Error('opts.units is required');
            if (!conversations?.length) throw new Error('opts.conversations is required');

            const m  = codes.length;
            const rn = Math.min(removeNum, m - 3);   // never reduce below 3 codes
            const empty = { removed: [], removedIndices: [], k: 0, variance: null };
            if (rn < 1) return empty;

            const gofDims  = Math.min(dims, 2);       // R scores on dims 1:2
            const baseOpts = { codes, units, conversations, window: windowSize,
                               binary, ordered, rotation, dims, gParams, groupA, groupB };

            const D = gofDims;  // score on the first 2 dims (R's get_pria_scores_2Ds)
            // Extract a D-column submatrix (given row indices) from a flat
            // row-major (nRows × dims) array.
            const sub = (flat, rowIdxs) => {
                const out = new Float64Array(rowIdxs.length * D);
                rowIdxs.forEach((r, t) => { for (let d = 0; d < D; d++) out[t * D + d] = flat[r * dims + d]; });
                return out;
            };
            // ena_correlation(A, B) → [r_dim0, r_dim1] (col 0 of the dims×3 result).
            const corr2 = (Aflat, Bflat, nRows) => {
                const r = qe.ena_correlation(Array.from(Aflat), nRows, D,
                                             Array.from(Bflat), nRows, D, 0.95);
                const out = [];
                for (let d = 0; d < D; d++) out.push(r.data[d * 3]);
                return out;
            };
            const full   = api.fit(rows, baseOpts);
            const nUnits = full.nUnits;
            const unitRows = Array.from({ length: nUnits }, (_, i) => i);
            const gofOf    = (mdl) => corr2(sub(mdl.points, unitRows), sub(mdl.model.centroids, unitRows), nUnits);
            const gFull    = gofOf(full);
            const fullPts2 = sub(full.points, unitRows);

            // All k-subsets of [0..m) as index arrays.
            const combos = (n, k) => {
                const res = [], cur = [];
                const rec = (start) => {
                    if (cur.length === k) { res.push(cur.slice()); return; }
                    for (let i = start; i < n; i++) { cur.push(i); rec(i + 1); cur.pop(); }
                };
                rec(0);
                return res;
            };

            let bestK = 0, bestVar = -Infinity, bestRemoved = [];
            for (let k = 1; k <= rn; k++) {
                for (const idxs of combos(m, k)) {
                    const removedSet = new Set(idxs);
                    const mask = [];
                    for (let i = 0; i < m; i++) {
                        const row = [];
                        for (let j = 0; j < m; j++) {
                            row.push((removedSet.has(i) || removedSet.has(j)) ? 0 : 1);
                        }
                        mask.push(row);
                    }
                    const red = api.fit(rows, { ...baseOpts, codeMask: mask });

                    // Gate 1 — goodness-of-fit ratio vs full, per dim.
                    const gRed = gofOf(red);
                    let pass = true;
                    for (let d = 0; d < D; d++) {
                        if (gFull[d] === 0 || gRed[d] / gFull[d] < threshold) { pass = false; break; }
                    }
                    if (!pass) continue;

                    // Gate 2 — reduced points AND retained-code nodes must each
                    // correlate >= threshold with the full model (per dim, with a
                    // per-dim sign flip that negates the node corr alongside it).
                    const retained = [];
                    for (let i = 0; i < m; i++) if (!removedSet.has(i)) retained.push(i);
                    let [pc1, pc2] = corr2(fullPts2, sub(red.points, unitRows), nUnits);
                    let [nc1, nc2] = corr2(sub(full.rotation.nodes, retained),
                                           sub(red.rotation.nodes, retained), retained.length);
                    if (pc1 < 0) { pc1 = -pc1; nc1 = -nc1; }
                    if (pc2 < 0) { pc2 = -pc2; nc2 = -nc2; }
                    if (Math.min(pc1, pc2, nc1, nc2) < threshold) continue;

                    // Dim-1 variance proportion over the FULL rotation spectrum
                    // (= R's set$model$variance[1] = diag(var(points.rotated))/sum);
                    // NOT model.variance, which is the 2-dim projected ratio.
                    const ev = red.rotation.eigenvalues;
                    let evSum = 0; for (let i = 0; i < ev.length; i++) evSum += ev[i];
                    const vr1 = evSum > 0 ? ev[0] / evSum : 0;
                    // Prefer more codes removed; tie-break on higher dim-1 variance.
                    if (k > bestK || (k === bestK && vr1 > bestVar)) {
                        bestK = k; bestVar = vr1; bestRemoved = idxs.slice();
                    }
                }
            }
            return {
                removed:        bestRemoved.map(i => codes[i]),
                removedIndices: bestRemoved,
                k:              bestK,
                variance:       bestVar === -Infinity ? null : bestVar,
            };
        },

        /**
         * Helpers re-exported for consumers who want to build their own pipeline.
         */
        defaultTensor,

        /** The underlying libqe WASM module, for custom low-level pipelines. */
        qe,
    };

    return api;
}
