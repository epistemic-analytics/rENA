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

// ── accumulation ─────────────────────────────────────────────────────────────

/**
 * Accumulate windowed co-occurrences for all units across all conversations.
 *
 * For each conversation group, runs qe.accumulate_stanza() on the conversation's
 * rows to get per-row connection vectors, then folds each row's vector into its
 * owning unit's running sum.
 *
 * @param {object}      qe            libqe WASM module
 * @param {Float64Array} codeMatrix   n_rows × n_codes, row-major
 * @param {number}      nRows
 * @param {number}      nCodes
 * @param {number}      nUnits
 * @param {Int32Array}  unitOf        unit index per row
 * @param {Map}         convoGroups   convoIdx → [rowIdx, ...]
 * @param {number}      windowSize    backward window (rows)
 * @param {boolean}     binary        binarise co-occurrences
 *
 * @returns {Float64Array}  nUnits × nConnections, row-major
 */
export function accumulate(qe, codeMatrix, nRows, nCodes, nUnits,
                            unitOf, convoGroups, windowSize = 4, binary = true) {
    const nConnections = qe.choose_two(nCodes);
    const networks     = new Float64Array(nUnits * nConnections);

    for (const [, rowIndices] of convoGroups) {
        const nConvo = rowIndices.length;

        // Extract code rows for this conversation (contiguous sub-matrix)
        const convoCodes = new Float64Array(nConvo * nCodes);
        for (let r = 0; r < nConvo; r++) {
            const src = rowIndices[r];
            convoCodes.set(
                codeMatrix.subarray(src * nCodes, src * nCodes + nCodes),
                r * nCodes
            );
        }

        // Windowed accumulation — returns per-row connection vectors
        const stanza = qe.accumulate_stanza(
            convoCodes, nConvo, nCodes, windowSize, 0, binary
        );
        // stanza.data: nConvo × nConnections, row-major

        // Fold each row into its unit's accumulator
        for (let r = 0; r < nConvo; r++) {
            const unit   = unitOf[rowIndices[r]];
            const offset = r * nConnections;
            for (let c = 0; c < nConnections; c++) {
                networks[unit * nConnections + c] += stanza.data[offset + c];
            }
        }
    }

    return networks;
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

// ── centering ─────────────────────────────────────────────────────────────────

/**
 * Subtract column means (center the network space).
 * Excludes all-zero rows from the mean calculation (zero-network exclusion).
 */
export function center(qe, networks, nUnits, nConnections) {
    // Identify non-zero rows
    const active = [];
    for (let u = 0; u < nUnits; u++) {
        let rowSum = 0;
        for (let c = 0; c < nConnections; c++) rowSum += Math.abs(networks[u * nConnections + c]);
        if (rowSum > 0) active.push(u);
    }

    // Compute column means over active rows only
    const means = new Float64Array(nConnections);
    for (const u of active) {
        for (let c = 0; c < nConnections; c++) means[c] += networks[u * nConnections + c];
    }
    if (active.length > 0) {
        for (let c = 0; c < nConnections; c++) means[c] /= active.length;
    }

    // Subtract means from all rows
    const centered = new Float64Array(networks.length);
    for (let u = 0; u < nUnits; u++) {
        for (let c = 0; c < nConnections; c++) {
            centered[u * nConnections + c] = networks[u * nConnections + c] - means[c];
        }
    }

    return centered;
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
 * Compute code node positions via least-squares.
 * @returns {{ nodes: Float64Array, nodeRows: number, nodeCols: number }}
 */
export function nodePositions(qe, networks, nUnits, nConnections, points, nDims) {
    const r = qe.node_positions(networks, nUnits, nConnections, points, nUnits, nDims);
    return {
        nodes:     new Float64Array(r.nodes.data),
        nodeRows:  r.nodes.rows,
        nodeCols:  r.nodes.cols,
    };
}
