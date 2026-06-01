/**
 * @qe-libs/rena-wasm
 *
 * JavaScript/WebAssembly ENA pipeline.
 * Thin orchestration layer over @qe-libs/libqe-wasm — handles data parsing,
 * unit/conversation grouping, and the full accumulate→normalize→center→
 * rotate→project→node-positions pipeline.
 *
 * Usage:
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
         * @param {string[]} opts.codes          - Code column names
         * @param {string[]} opts.units          - Unit identifier column(s)
         * @param {string[]} opts.conversations  - Conversation identifier column(s)
         * @param {number}   [opts.window=4]     - Backward accumulation window
         * @param {boolean}  [opts.binary=true]  - Binarise co-occurrences
         * @param {string}   [opts.rotation='svd'] - 'svd' or 'mean'
         * @param {number[]} [opts.groupA]       - Unit row indices for means rotation group A
         * @param {number[]} [opts.groupB]       - Unit row indices for means rotation group B
         * @param {number}   [opts.dims=2]       - Number of dimensions to return
         *
         * @returns {ENAModel}
         */
        fit(rows, opts = {}) {
            const {
                codes,
                units,
                conversations,
                window:     windowSize  = 4,
                binary                  = true,
                rotation:   rotMethod   = 'svd',
                groupA,
                groupB,
                dims                    = 2,
            } = opts;

            if (!codes?.length)         throw new Error('opts.codes is required');
            if (!units?.length)         throw new Error('opts.units is required');
            if (!conversations?.length) throw new Error('opts.conversations is required');

            // 1. Parse
            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups } = parseData(rows, codes, units, conversations);

            const nConnections  = qe.choose_two(nCodes);
            const connectionNames = qe.connection_names(codes);

            // 2. Accumulate
            const rawNetworks = accumulate(
                qe, codeMatrix, nRows, nCodes, nUnits,
                unitOf, convoGroups, windowSize, binary
            );

            // 3. Sphere norm
            const normed = sphereNorm(qe, rawNetworks, nUnits, nConnections);

            // 4. Center (zero-network rows excluded from mean)
            const centered = center(qe, normed, nUnits, nConnections);

            // 5. Rotate
            let rot;
            if (rotMethod === 'mean') {
                if (!groupA || !groupB) throw new Error(
                    'opts.groupA and opts.groupB are required for means rotation'
                );
                rot = rotateMeans(qe, centered, nUnits, nConnections, groupA, groupB);
            } else {
                rot = rotateSVD(qe, centered, nUnits, nConnections);
            }

            // 6. Project
            const centroids = project(
                centered, nUnits, nConnections,
                rot.rotation, rot.rotRows, rot.rotCols, dims
            );

            // 7. Node positions
            const { nodes: positions } = nodePositions(
                qe, normed, nUnits, nConnections, centroids, dims
            );

            return new ENAModel({
                networks:        normed,
                centroids,
                positions,
                connectionNames,
                unitLabels,
                columnNames:     rot.columnNames.slice(0, dims),
                eigenvalues:     rot.eigenvalues,
                dims,
                nUnits,
                nConnections,
            });
        },

        /**
         * Run only the accumulation step.
         * Returns raw (un-normalised) network vectors.
         *
         * @param {Object[]} rows
         * @param {object}   opts  - codes, units, conversations, window, binary
         * @returns {{ networks: Float64Array, unitLabels: string[],
         *             connectionNames: string[], nUnits: number, nConnections: number }}
         */
        accumulate(rows, opts = {}) {
            const { codes, units, conversations,
                    window: windowSize = 4, binary = true } = opts;

            const { codeMatrix, nRows, nCodes, nUnits, unitLabels,
                    unitOf, convoGroups } = parseData(rows, codes, units, conversations);

            const nConnections    = qe.choose_two(nCodes);
            const connectionNames = qe.connection_names(codes);

            const networks = accumulate(
                qe, codeMatrix, nRows, nCodes, nUnits,
                unitOf, convoGroups, windowSize, binary
            );

            return { networks, unitLabels, connectionNames, nUnits, nConnections };
        },
    };
}
