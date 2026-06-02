/**
 * @qe-libs/rena-wasm
 *
 * JavaScript/WebAssembly ENA pipeline.
 * Thin orchestration layer over @qe-libs/libqe-wasm — handles data parsing,
 * unit/conversation grouping, and the full accumulate→normalize→center→
 * rotate→project→node-positions pipeline.
 *
 * Usage (simple windowed):
 *
 *   import loadENA from '@qe-libs/rena-wasm';
 *   const ena = await loadENA();
 *
 *   const model = ena.fit(rows, {
 *     codes:         ['Data', 'Technical.Constraints', ...],
 *     units:         ['UserName', 'Condition'],
 *     conversations: ['Condition', 'GroupName'],
 *     window:        4,
 *     rotation:      'svd',   // 'svd' | 'mean'
 *     dims:          2,
 *   });
 *
 * Usage (context tensor — advanced):
 *
 *   const model = ena.fit(rows, {
 *     codes, units, conversations,
 *     ordered: true,
 *     tensor: {
 *       // Tensor shape: [nSenderVals, nReceiverVals, 2].
 *       // Last entry is always 2 (index 0 = weight, index 1 = window).
 *       dims: [3, 3, 2],
 *       dimsSender:   [0],   // axis 0 = sender factor
 *       dimsReceiver: [1],   // axis 1 = receiver factor
 *       dimsMode:     [],
 *       // Factor column names (one per non-weight/window axis, in order).
 *       factors: ['SenderType', 'ReceiverType'],
 *       // Optional: explicit value → index mapping.  Inferred if omitted.
 *       factorLevels: {
 *         SenderType:   { 'A': 0, 'B': 1, 'C': 2 },
 *         ReceiverType: { 'X': 0, 'Y': 1, 'Z': 2 },
 *       },
 *       // Flat column-major tensor: weight and window per factor combination.
 *       // Length = product(dims).
 *       data: new Float64Array([...]),
 *       // Optional timestamp column.  Defaults to row index.
 *       timesCol: 'timestamp',
 *     },
 *   });
 *
 *   // model.centroids       Float64Array  (nUnits × dims)
 *   // model.networks        Float64Array  (nUnits × nConnections) — normed
 *   // model.positions       Float64Array  (nCodes × dims)
 *   // model.connectionNames string[]
 *   // model.unitLabels      string[]
 *   // model.dims            number
 */

import loadLibQE from '@qe-libs/libqe-wasm';
import { parseData } from './data.js';
import {
    accumulate, sphereNorm, center,
    rotateSVD, rotateMeans,
    project, nodePositions,
} from './pipeline.js';
import { accumulateTensor, defaultTensor } from './tensor.js';

// ── ENA result object ─────────────────────────────────────────────────────────

class ENAModel {
    /**
     * @param {object} opts
     * @param {Float64Array} opts.networks        normed adjacency vectors (nUnits × nConnections)
     * @param {Float64Array} opts.centroids        unit positions (nUnits × dims)
     * @param {Float64Array} opts.positions        node positions (nCodes × dims)
     * @param {string[]}     opts.connectionNames  e.g. ['Data & Technical.Constraints', ...]
     * @param {string[]}     opts.unitLabels
     * @param {string[]}     opts.columnNames      rotation axis labels e.g. ['SVD1', 'SVD2']
     * @param {number[]}     opts.eigenvalues
     * @param {number}       opts.dims
     * @param {number}       opts.nUnits
     * @param {number}       opts.nConnections
     */
    constructor(opts) {
        Object.assign(this, opts);
    }

    /** Centroid for a single unit by label. */
    centroid(unitLabel) {
        const idx = this.unitLabels.indexOf(unitLabel);
        if (idx < 0) throw new Error(`Unknown unit: ${unitLabel}`);
        return Array.from(this.centroids.subarray(idx * this.dims, (idx + 1) * this.dims));
    }

    /** Network vector for a single unit by label. */
    network(unitLabel) {
        const idx = this.unitLabels.indexOf(unitLabel);
        if (idx < 0) throw new Error(`Unknown unit: ${unitLabel}`);
        return Array.from(this.networks.subarray(idx * this.nConnections, (idx + 1) * this.nConnections));
    }
}

// ── shared pipeline (post-accumulation) ──────────────────────────────────────

function runPipeline(qe, rawNetworks, nUnits, nConnections, codes, unitLabels,
                     rotMethod, groupA, groupB, dims) {
    const connectionNames = qe.connection_names(codes);

    // Sphere norm
    const normed = sphereNorm(qe, rawNetworks, nUnits, nConnections);

    // Center (zero-network rows excluded from mean)
    const centered = center(qe, normed, nUnits, nConnections);

    // Rotate
    let rot;
    if (rotMethod === 'mean') {
        if (!groupA || !groupB) throw new Error(
            'opts.groupA and opts.groupB are required for means rotation'
        );
        rot = rotateMeans(qe, centered, nUnits, nConnections, groupA, groupB);
    } else {
        rot = rotateSVD(qe, centered, nUnits, nConnections);
    }

    // Project
    const centroids = project(
        centered, nUnits, nConnections,
        rot.rotation, rot.rotRows, rot.rotCols, dims
    );

    // Node positions
    const { nodes: positions } = nodePositions(
        qe, normed, nUnits, nConnections, centroids, dims
    );

    return new ENAModel({
        networks:     normed,
        centroids,
        positions,
        connectionNames,
        unitLabels,
        columnNames:  rot.columnNames.slice(0, dims),
        eigenvalues:  rot.eigenvalues,
        dims,
        nUnits,
        nConnections,
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

    return {
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
         * @param {object}   [opts.tensor]         - Context tensor definition (see module docstring)
         * @param {string}   [opts.rotation='svd'] - 'svd' or 'mean'
         * @param {number[]} [opts.groupA]         - Unit indices for means rotation group A
         * @param {number[]} [opts.groupB]         - Unit indices for means rotation group B
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
                dims                 = 2,
            } = opts;

            if (!codes?.length)         throw new Error('opts.codes is required');
            if (!units?.length)         throw new Error('opts.units is required');
            if (!conversations?.length) throw new Error('opts.conversations is required');

            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups } = parseData(rows, codes, units, conversations);

            let rawNetworks, nConnections;

            if (tensorDef) {
                // Advanced: context-tensor accumulation
                rawNetworks  = accumulateTensor(
                    qe, rows, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, tensorDef, ordered
                );
                nConnections = ordered ? nCodes * nCodes : qe.choose_two(nCodes);
            } else {
                // Simple: windowed stanza accumulation
                rawNetworks  = accumulate(
                    qe, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, windowSize, binary
                );
                nConnections = qe.choose_two(nCodes);
            }

            return runPipeline(qe, rawNetworks, nUnits, nConnections, codes,
                               unitLabels, rotMethod, groupA, groupB, dims);
        },

        /**
         * Run only the accumulation step.
         * Returns raw (un-normalised) network vectors.
         *
         * @param {Object[]} rows
         * @param {object}   opts  - codes, units, conversations, window, binary, ordered, tensor
         * @returns {{ networks: Float64Array, unitLabels: string[],
         *             connectionNames: string[], nUnits: number, nConnections: number }}
         */
        accumulate(rows, opts = {}) {
            const {
                codes, units, conversations,
                window:  windowSize = 4,
                binary               = true,
                ordered              = false,
                tensor:  tensorDef,
            } = opts;

            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups } = parseData(rows, codes, units, conversations);

            let networks, nConnections;

            if (tensorDef) {
                networks     = accumulateTensor(
                    qe, rows, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, tensorDef, ordered
                );
                nConnections = ordered ? nCodes * nCodes : qe.choose_two(nCodes);
            } else {
                networks     = accumulate(
                    qe, codeMatrix, nRows, nCodes, nUnits,
                    unitOf, convoGroups, windowSize, binary
                );
                nConnections = qe.choose_two(nCodes);
            }

            const connectionNames = qe.connection_names(codes);
            return { networks, unitLabels, connectionNames, nUnits, nConnections };
        },

        /**
         * Helpers re-exported for consumers who want to build their own pipeline.
         */
        defaultTensor,
    };
}
