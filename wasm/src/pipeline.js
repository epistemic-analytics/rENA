/**
 * pipeline.js — ENA pipeline steps backed by @qe-libs/libqe-wasm.
 *
 * All functions take a libqe module instance (`qe`) as first argument so
 * they work in both Node and browser contexts without global state.
 */

// ── helpers ───────────────────────────────────────────────────────────────────

/**
 * Multiply two row-major matrices: A (m×k) @ B (k×n) → C (m×n).
 * Used for projection (networks @ rotation_matrix).
 */
export function matmul(A, m, k, B, n) {
    const C = new Float64Array(m * n);
    for (let r = 0; r < m; r++) {
        for (let c = 0; c < n; c++) {
            let sum = 0;
            for (let i = 0; i < k; i++) sum += A[r * k + i] * B[i * n + c];
            C[r * n + c] = sum;
        }
    }
    return C;
}

/**
 * Extract the first `nDims` columns of a row-major matrix.
 */
export function sliceCols(data, nRows, nCols, nDims) {
    if (nDims >= nCols) return data;
    const out = new Float64Array(nRows * nDims);
    for (let r = 0; r < nRows; r++)
        for (let c = 0; c < nDims; c++)
            out[r * nDims + c] = data[r * nCols + c];
    return out;
}

/**
 * Pearson correlation of two paired numeric vectors.
 * Returns NaN if either vector has zero variance.
 */
function pearson(x, y) {
    const n = x.length;
    if (n === 0) return NaN;
    let mx = 0, my = 0;
    for (let i = 0; i < n; i++) { mx += x[i]; my += y[i]; }
    mx /= n; my /= n;
    let sxy = 0, sxx = 0, syy = 0;
    for (let i = 0; i < n; i++) {
        const dx = x[i] - mx, dy = y[i] - my;
        sxy += dx * dy; sxx += dx * dx; syy += dy * dy;
    }
    const denom = Math.sqrt(sxx * syy);
    return denom === 0 ? NaN : sxy / denom;
}

/**
 * Pearson correlation between the pairwise distances of two ENA spaces.
 *
 * Computes the Euclidean distance between every pair of points within `A` and
 * within `B` (same pairing for both), then correlates the two distance vectors.
 * Because pairwise distances are invariant to rotation/reflection of a space,
 * this measures configuration similarity up to an orthogonal transform — the
 * right tool for comparing ENA solutions across window sizes whose SVD axes may
 * flip sign. Mirrors R's ena_space_dist_corr: exact for small spaces, sampled
 * (with replacement, self-pairs dropped) once unique pairs exceed the limit.
 *
 * @param {Float64Array} A               m × d, row-major
 * @param {Float64Array} B               m × d, row-major
 * @param {number}       m               number of points (rows)
 * @param {number}       d               dimensions (cols)
 * @param {number}       [maxSampleSize=100000]
 * @param {() => number} [rand=Math.random]  RNG for the sampled path
 * @returns {number}  Pearson correlation of the paired distance vectors
 */
export function spaceDistCorr(A, B, m, d, maxSampleSize = 100000, rand = Math.random) {
    if (!m || m === 0) throw new Error('The spaces must have a non-zero number of rows.');

    const dist = (M, p, q) => {
        let s = 0;
        for (let c = 0; c < d; c++) {
            const diff = M[p * d + c] - M[q * d + c];
            s += diff * diff;
        }
        return Math.sqrt(s);
    };

    const totalPairs = (m * (m - 1)) / 2;

    let distA, distB;
    if (totalPairs <= maxSampleSize) {
        // Exact: all unique i<j pairs.
        distA = new Float64Array(totalPairs);
        distB = new Float64Array(totalPairs);
        let k = 0;
        for (let i = 0; i < m; i++)
            for (let j = i + 1; j < m; j++) {
                distA[k] = dist(A, i, j);
                distB[k] = dist(B, i, j);
                k++;
            }
    } else {
        // Sample pairs with replacement, drop self-pairs.
        const a = [], b = [];
        for (let s = 0; s < maxSampleSize; s++) {
            const i = Math.floor(rand() * m);
            const j = Math.floor(rand() * m);
            if (i === j) continue;
            a.push(dist(A, i, j));
            b.push(dist(B, i, j));
        }
        distA = Float64Array.from(a);
        distB = Float64Array.from(b);
    }

    return pearson(distA, distB);
}

// ── normalization (sphere norm) ───────────────────────────────────────────────

/**
 * L2-normalize each row (sphere normalization).
 * Rows with zero norm are left as zero.
 */
export function sphereNorm(qe, networks, nUnits, nConnections) {
    const result = qe.normalize_networks(networks, nUnits, nConnections);
    return new Float64Array(result.data);
}

/**
 * Scale every network by the reciprocal of the largest row L2 norm, keeping
 * relative magnitudes across units (= rENA's fun_skip_sphere_norm, used when
 * sphere normalization is off).
 */
export function scaleNetworks(qe, networks, nUnits, nConnections) {
    const result = qe.scale_networks(networks, nUnits, nConnections);
    return new Float64Array(result.data);
}

// ── centering ─────────────────────────────────────────────────────────────────

/**
 * Subtract column means (center the network space).
 * Excludes all-zero rows from the mean calculation (zero-network exclusion).
 *
 * @param {boolean} [shiftZeroRows=false]  Also subtract the mean from all-zero
 *   rows, as rENA's center(exclude_zero_networks = TRUE) does -- the ONA
 *   convention (ona::model). By default zero-network rows stay at zero, as in
 *   rENA's ena.make.set().
 * @param {boolean} [includeZeroRows=false]  Take the mean over every row,
 *   zero networks included, and shift every row by it: rENA's
 *   ena.make.set(center.align.to.origin = FALSE). Overrides shiftZeroRows.
 * @returns {{ centered: Float64Array, centerVec: Float64Array }}
 *   centered  — mean-subtracted networks
 *   centerVec — the column means used for centering (= R's rotation$center.vec)
 */
export function center(qe, networks, nUnits, nConnections, shiftZeroRows = false,
                       includeZeroRows = false) {
    // Identify non-zero rows (every row when zero networks are included)
    const active = [];
    for (let u = 0; u < nUnits; u++) {
        let rowSum = 0;
        for (let c = 0; c < nConnections; c++) rowSum += Math.abs(networks[u * nConnections + c]);
        if (rowSum > 0 || includeZeroRows) active.push(u);
    }

    // Compute column means over active rows only (= R's rotation$center.vec)
    const means = new Float64Array(nConnections);
    for (const u of active) {
        for (let c = 0; c < nConnections; c++) means[c] += networks[u * nConnections + c];
    }
    if (active.length > 0) {
        for (let c = 0; c < nConnections; c++) means[c] /= active.length;
    }

    // Subtract means from non-zero rows only.
    // Zero-network rows remain at zero (R: center.align.to.origin = TRUE default).
    const activeSet = new Set(active);
    const centered  = new Float64Array(networks.length);
    for (let u = 0; u < nUnits; u++) {
        if (!shiftZeroRows && !includeZeroRows && !activeSet.has(u)) continue;   // leave zero-network row as zero
        for (let c = 0; c < nConnections; c++) {
            centered[u * nConnections + c] = networks[u * nConnections + c] - means[c];
        }
    }

    return { centered, centerVec: means };
}

// ── rotation ──────────────────────────────────────────────────────────────────

/**
 * SVD rotation (default ENA rotation).
 * @returns {{ rotation: Float64Array, rotRows: number, rotCols: number,
 *             eigenvalues: number[], columnNames: string[] }}
 */
export function rotateSVD(qe, centered, nUnits, nConnections) {
    const r = qe.ena_svd(centered, nUnits, nConnections);
    return {
        rotation:    r.rotation.data,
        rotRows:     r.rotation.rows,
        rotCols:     r.rotation.cols,
        eigenvalues: r.eigenvalues,
        columnNames: r.column_names,
    };
}

/**
 * Means rotation.
 * @param {Int32Array[]} groupA  Row indices of group A
 * @param {Int32Array[]} groupB  Row indices of group B
 */
export function rotateMeans(qe, centered, nUnits, nConnections, groupA, groupB) {
    const groupPairs = [{ a: new Int32Array(groupA), b: new Int32Array(groupB) }];
    const r = qe.means_rotation(centered, nUnits, nConnections, groupPairs);
    return {
        rotation:    r.rotation.data,
        rotRows:     r.rotation.rows,
        rotCols:     r.rotation.cols,
        eigenvalues: r.eigenvalues,
        columnNames: r.column_names,
    };
}

/**
 * Generalized Means Rotation (GMR).
 *
 * Mirrors R's ena.rotate.by.generalized() / libqe::generalized_means_rotation().
 * Handles Lasso-adjusted OLS covariate control, between-group scatter for
 * categorical targets, optional Y axis, and SVD completion.
 *
 * All matrix inputs are row-major Float64Arrays; all index arrays are Int32Arrays.
 *
 * @param {object}       qe
 * @param {Float64Array} centered         nUnits × nConnections, row-major
 * @param {number}       nUnits
 * @param {number}       nConnections
 * @param {object}       p                Pre-built GMR parameters
 * @param {Float64Array} p.xModelMatrix   nUnits × xmCols row-major model matrix
 *                                        (treatment coding, reference = level[0])
 * @param {number}       p.xmRows         must equal nUnits
 * @param {number}       p.xmCols         number of dummy columns (nGroups - 1)
 * @param {Float64Array} p.xTarget        nUnits — 0-based integer codes for target
 * @param {Int32Array}   p.x1Cols         0-based column indices in xModelMatrix for the target
 * @param {boolean}      p.xCategorical
 * @param {number}       p.xNGroups       number of distinct levels
 * @param {Int32Array}   p.xSubset        0-based unit-row indices used for GMR fit
 * @param {boolean}      [p.hasY=false]   whether a Y-axis GMR target is provided
 * @param {Float64Array} [p.yModelMatrix] (ignored when hasY=false)
 * @param {number}       [p.ymRows]
 * @param {number}       [p.ymCols]
 * @param {Float64Array} [p.yTarget]
 * @param {Int32Array}   [p.y1Cols]
 * @param {boolean}      [p.yCategorical=false]
 * @param {number}       [p.yNGroups=0]
 * @param {number}       [p.nLambda=50]
 * @param {number}       [p.kFolds=5]
 * @param {number}       [p.lassoEps=0.01]
 * @returns {{ rotation, rotRows, rotCols, eigenvalues, columnNames }}
 */
export function rotateGeneralized(qe, centered, nUnits, nConnections, p) {
    const hasY    = !!p.hasY;
    const nLambda = (p.nLambda  ?? 50)   | 0;
    const kFolds  = (p.kFolds   ?? 5)    | 0;
    const lassoEps = p.lassoEps ?? 0.01;

    // Stub Y params when hasY=false — C++ ignores them but still needs valid arrays.
    const yMM   = hasY ? p.yModelMatrix : new Float64Array(nUnits);
    const ymR   = hasY ? (p.ymRows | 0) : nUnits;
    const ymC   = hasY ? (p.ymCols | 0) : 1;
    const yTgt  = hasY ? p.yTarget      : new Float64Array(nUnits);
    const y1C   = hasY ? p.y1Cols       : new Int32Array([0]);
    const yCat  = hasY ? !!p.yCategorical : false;
    const yNGrp = hasY ? ((p.yNGroups || 0) | 0) : 0;

    let r;
    try {
        r = qe.generalized_means_rotation(
            centered,        nUnits,        nConnections,
            p.xModelMatrix,  p.xmRows | 0,  p.xmCols | 0,
            p.xTarget,
            p.x1Cols,
            !!p.xCategorical, (p.xNGroups | 0),
            p.xSubset,
            hasY,
            yMM,  ymR,  ymC,
            yTgt,
            y1C,
            yCat,  yNGrp,
            nLambda, kFolds, lassoEps
        );
    } catch (err) {
        throw new Error(
            'Rotation by Regression failed: the target variable or group selection ' +
            'has zero variance or insufficient rank across units.'
        );
    }

    return {
        rotation:    r.rotation.data,
        rotRows:     r.rotation.rows,
        rotCols:     r.rotation.cols,
        eigenvalues: r.eigenvalues,
        columnNames: r.column_names,
    };
}

// ── projection & node positions ───────────────────────────────────────────────

/**
 * Project centered networks into the rotated ENA space.
 * @returns {Float64Array}  nUnits × nDims, row-major
 */
export function project(centered, nUnits, nConnections, rotation, rotRows, rotCols, nDims) {
    const fullPoints = matmul(centered, nUnits, nConnections, rotation, rotCols);
    return sliceCols(fullPoints, nUnits, rotCols, nDims);
}

/**
 * Compute code node positions via least-squares (LWS).
 *
 * @param {boolean} [directed=false]  Use libqe's directed_node_positions (for
 *   ordered n² networks), as rENA's optimize() does for ordered sets.
 * @returns {{ nodes: Float64Array, nodeRows: number, nodeCols: number,
 *             centroids: Float64Array|null }}
 *   nodes     — code positions in ENA space (= R's rotation$nodes)
 *   centroids — LWS unit centroid positions (= R's model$centroids), or null
 *               if libqe does not expose them
 */
export function nodePositions(qe, networks, nUnits, nConnections, points, nDims, directed = false) {
    const solve = directed ? qe.directed_node_positions : qe.node_positions;
    const r = solve(networks, nUnits, nConnections, points, nUnits, nDims, nDims);
    return {
        nodes:     new Float64Array(r.nodes.data),
        nodeRows:  r.nodes.rows,
        nodeCols:  r.nodes.cols,
        centroids: r.centroids ? new Float64Array(r.centroids.data) : null,
    };
}
