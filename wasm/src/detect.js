/**
 * detect.js — heuristic ENA model-parameter detection.
 *
 * Given parsed tabular rows (array of plain objects, one per row, keyed by
 * column name), suggest which columns are ENA codes, units, and conversations
 * (a.k.a. horizons), plus a likely group/comparison column.
 *
 * Pure JS heuristics — no WASM required, so this is exported synchronously
 * alongside the async `loadENA()` factory. Parse data however you like
 * (PapaParse, d.ply, etc.), then pass the rows:
 *
 *   import { detectParams } from '@qe-libs/rena-wasm';
 *   const r = detectParams(rows);
 *   // r.codes / r.units / r.conversations / r.groups / r.columns
 *   // r.recommended / r.confidence / r.reason
 */

// Helper to split a column name into lowercase alphanumeric tokens.
// Handles camelCase, snake_case, dot.case, hyphen-case, etc.
function getTokens(str) {
    const camelSplit = str.replace(/([a-z])([A-Z])/g, '$1 $2');
    return camelSplit.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
}

// ── name-hint vocabularies ──────────────────────────────────────────────────────

const UNIT_HINTS  = new Set(['user', 'student', 'participant', 'speaker', 'person',
                             'author', 'subject', 'respondent', 'id', 'name', 'who',
                             'group', 'condition', 'class', 'team',
                             'player', 'character', 'actor', 'agent']);
const CONVO_HINTS = new Set(['group', 'condition', 'session', 'conversation', 'convo',
                             'episode', 'class', 'team', 'day', 'week', 'period',
                             'context', 'case', 'trial', 'horizon', 'activity', 'task',
                             'problem', 'scenario', 'phase', 'stage', 'run', 'round',
                             'turn', 'half',
                             'play', 'act', 'scene', 'chapter', 'section']);
// Names implying free text, scores, or metadata — never codes/units/conversations.
const EXCLUDE = new Set([
    'timestamp', 'timestamps', 'time', 'times', 'date', 'dates', 'text', 'texts',
    'utterance', 'utterances', 'message', 'messages', 'content', 'contents',
    'line', 'lines', 'row', 'rows', 'index', 'indices', 'notes', 'note',
    'score', 'scores', 'grade', 'grades', 'level', 'levels', 'change', 'changes',
    'pre', 'post', 'confidence', 'values', 'value', 'vals', 'val', 'rates', 'rate',
    'rating', 'ratings'
]);

// ── column classifiers ──────────────────────────────────────────────────────────

/** A code column: every non-empty value is 0 or 1. */
export function isBinary(rows, col) {
    const vals = new Set(rows.map(r => r[col]).filter(v => v !== '' && v != null));
    return vals.size > 0 && [...vals].every(v => v === '0' || v === '1' || v === 0 || v === 1);
}

/** Score a column as a UNIT-of-analysis candidate (0–1). 0 = not a candidate. */
export function scoreUnit(col, nUnique, nRows) {
    const tokens = getTokens(col);
    if (nUnique < 2 || nUnique > Math.min(nRows * 0.8, 1000)) return 0;
    let s = 0.3;
    if (tokens.some(t => UNIT_HINTS.has(t))) s += 0.5;
    if (nUnique >= 2 && nUnique <= 200) s += 0.2;
    return Math.min(s, 1.0);
}

/** Score a column as a CONVERSATION / horizon (segmentation) candidate (0–1). */
export function scoreConvo(col, nUnique, nRows) {
    const tokens = getTokens(col);
    if (nUnique < 2 || nUnique > Math.min(nRows * 0.5, 500)) return 0;
    let s = 0.2;
    if (tokens.some(t => CONVO_HINTS.has(t))) s += 0.6;
    if (nUnique >= 2 && nUnique <= 100) s += 0.2;
    return Math.min(s, 1.0);
}

const round2 = v => Math.round(v * 100) / 100;

// ── main entry point ────────────────────────────────────────────────────────────

/**
 * Detect ENA model parameters from parsed rows.
 *
 * @param {Object[]} rows  Array of row objects keyed by column name.
 * @returns {{
 *   recommended: boolean,
 *   confidence: 'high'|'medium'|'low',
 *   reason: string,
 *   nRows: number,
 *   nCols: number,
 *   codes: string[],
 *   units: {column:string,nUnique:number,score:number}[],
 *   conversations: {column:string,nUnique:number,score:number}[],
 *   groups: Record<string,string[]>,
 *   columns: {name:string,nUnique:number,role:string}[],
 * }}
 */
export function detectParams(rows) {
    const nRows   = Array.isArray(rows) ? rows.length : 0;
    const headers = nRows > 0 ? Object.keys(rows[0]) : [];

    const codeCols   = [];
    const columnsData = {};

    // First pass: identify roles, compute nUnique, basic unit/convo scores
    for (const col of headers) {
        const tokens = getTokens(col);
        const vals      = rows.map(r => r[col]).filter(v => v !== '' && v != null);
        const nUnique   = new Set(vals).size;

        // Calculate variance of string lengths to identify free-text/dialogue columns
        let lenVar = 0;
        if (vals.length > 1) {
            const lengths = vals.map(v => String(v).length);
            const mean = lengths.reduce((a, b) => a + b, 0) / lengths.length;
            lenVar = lengths.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / lengths.length;
        }

        if (tokens.some(t => EXCLUDE.has(t)) || lenVar > 100) {
            columnsData[col] = { role: 'metadata', nUnique, uScore: 0, cScore: 0 };
            continue;
        }

        if (isBinary(rows, col)) {
            codeCols.push(col);
            columnsData[col] = { role: 'code', nUnique, uScore: 0, cScore: 0 };
            continue;
        }

        const uScore = scoreUnit(col, nUnique, nRows);
        const cScore = scoreConvo(col, nUnique, nRows);
        columnsData[col] = { role: 'candidate', nUnique, uScore, cScore };
    }

    // Find the primary unit column (highest uScore, tie-break by nUnique)
    let primaryUnitCol = null;
    let maxUScore = -1;
    let maxUnique = -1;

    for (const col of headers) {
        const data = columnsData[col];
        if (data.role !== 'candidate') continue;
        if (data.uScore > maxUScore || (data.uScore === maxUScore && data.nUnique > maxUnique)) {
            maxUScore = data.uScore;
            maxUnique = data.nUnique;
            primaryUnitCol = col;
        }
    }

    // Second pass: apply split penalty for units, and nesting penalty for conversations
    const unitCands  = [];   // [score, col, nUnique]
    const convoCands = [];
    const columns    = [];

    // Identify which columns are valid conversation candidates to check nesting
    const convoCandidateCols = headers.filter(col => {
        const data = columnsData[col];
        return data && data.role === 'candidate' && data.cScore > 0;
    });

    for (const col of headers) {
        const data = columnsData[col];
        if (data.role === 'metadata') {
            columns.push({ name: col, nUnique: data.nUnique, role: 'metadata' });
            continue;
        }
        if (data.role === 'code') {
            columns.push({ name: col, nUnique: data.nUnique, role: 'code' });
            continue;
        }

        let uScore = data.uScore;
        let cScore = data.cScore;

        if (col === primaryUnitCol) {
            uScore = data.uScore;
        } else if (primaryUnitCol) {
            // Check if combining col with primaryUnitCol increases the number of unique units
            const combinedVals = rows.map(r => `${r[primaryUnitCol]}|||${r[col]}`).filter(v => !v.includes('null') && !v.includes('undefined'));
            const nCombinedUnique = new Set(combinedVals).size;

            if (nCombinedUnique > maxUnique) {
                // Splits the primary unit into multiple smaller units. Penalize the score.
                uScore = Math.max(0, uScore - 0.25);
            }
        }

        // Conversation nesting penalty: B is nested under A if B has more unique values,
        // and combining A + B doesn't increase unique combinations beyond soft-nesting limit.
        if (cScore > 0) {
            let nParents = 0;
            for (const parentCol of convoCandidateCols) {
                if (parentCol === col) continue;
                const parentData = columnsData[parentCol];

                if (parentData.nUnique < data.nUnique) {
                    const combinedVals = rows.map(r => `${r[parentCol]}|||${r[col]}`).filter(v => !v.includes('null') && !v.includes('undefined'));
                    const nCombinedUnique = new Set(combinedVals).size;
                    const ratio = nCombinedUnique / data.nUnique;

                    if (ratio <= 2.5) {
                        nParents++;
                    }
                }
            }
            if (nParents > 0) {
                cScore = Math.max(0.1, cScore - nParents * 0.15);
            }
        }

        if (uScore > 0 || cScore > 0) {
            const role = uScore >= cScore ? 'unit_candidate' : 'conversation_candidate';
            if (uScore > 0) unitCands.push([uScore, col, data.nUnique]);
            if (cScore > 0) convoCands.push([cScore, col, data.nUnique]);
            columns.push({ name: col, nUnique: data.nUnique, role });
        } else {
            columns.push({ name: col, nUnique: data.nUnique, role: 'other' });
        }
    }

    unitCands.sort((a, b) => b[0] - a[0] || b[2] - a[2]);
    convoCands.sort((a, b) => b[0] - a[0] || a[2] - b[2]);

    const units = unitCands.slice(0, 5).map(([s, c, u]) =>
        ({ column: c, nUnique: u, score: round2(s) }));
    const conversations = convoCands.slice(0, 5).map(([s, c, u]) =>
        ({ column: c, nUnique: u, score: round2(s) }));

    // Compute suggested combined selections in the correct nesting order
    const suggestedUnits = [];
    if (primaryUnitCol) {
        // Find other unit columns that don't split the primary unit
        const nestingUnitCols = [];
        for (const [score, col, nUnique] of unitCands) {
            if (col === primaryUnitCol) continue;
            if (score >= 0.5) {
                const combinedVals = rows.map(r => `${r[primaryUnitCol]}|||${r[col]}`).filter(v => !v.includes('null') && !v.includes('undefined'));
                const nCombinedUnique = new Set(combinedVals).size;
                if (nCombinedUnique === maxUnique) {
                    nestingUnitCols.push({ col, nUnique });
                }
            }
        }
        // Sort nesting columns by nUnique ascending (broadest first)
        nestingUnitCols.sort((a, b) => a.nUnique - b.nUnique);
        nestingUnitCols.forEach(x => suggestedUnits.push(x.col));
        suggestedUnits.push(primaryUnitCol);
    }

    const suggestedConversations = [];
    if (convoCands.length > 0) {
        const convo1 = convoCands[0][1];
        const nUnique1 = convoCands[0][2];
        let convo2 = null;
        for (let i = 1; i < convoCands.length; i++) {
            const score = convoCands[i][0];
            const col = convoCands[i][1];
            const nUniqueCol = convoCands[i][2];
            if (score >= 0.5 && nUniqueCol > nUnique1) {
                const combinedVals = rows.map(r => `${r[convo1]}|||${r[col]}`).filter(v => !v.includes('null') && !v.includes('undefined'));
                const nCombinedUnique = new Set(combinedVals).size;
                const ratio = nCombinedUnique / nUniqueCol;
                if (ratio > 1.01) { // Orthogonal/crosses
                    convo2 = col;
                    break;
                }
            }
        }
        suggestedConversations.push(convo1);
        if (convo2) suggestedConversations.push(convo2);
    }

    // First convo candidate with a small, discrete value set → a comparison variable.
    const groups = {};
    for (const [, col, nUnique] of convoCands.slice(0, 3)) {
        if (nUnique >= 2 && nUnique <= 8) {
            groups[col] = [...new Set(rows.map(r => String(r[col])).filter(Boolean))].sort();
            break;
        }
    }

    const nCodes   = codeCols.length;
    const hasUnits = unitCands.length  > 0 && unitCands[0][0]  >= 0.3;
    const hasConvo = convoCands.length > 0 && convoCands[0][0] >= 0.2;

    let recommended, confidence, reason;
    if (nCodes >= 3 && hasUnits && hasConvo) {
        recommended = true;
        confidence  = nCodes >= 5 && unitCands[0][0] >= 0.7 ? 'high' : 'medium';
        reason = `Found ${nCodes} binary code columns, a likely unit column ` +
            `('${unitCands[0][1]}', ${unitCands[0][2]} unique values), and a likely ` +
            `conversation column ('${convoCands[0][1]}', ${convoCands[0][2]} unique values).`;
    } else if (nCodes >= 2 && (hasUnits || hasConvo)) {
        recommended = true;
        confidence  = 'low';
        reason = `Found ${nCodes} binary code column(s) and partial structure. ENA may be applicable.`;
    } else if (nCodes >= 2) {
        recommended = true;
        confidence  = 'low';
        reason = `Found ${nCodes} binary code columns but no clear unit/conversation columns by name.`;
    } else if (nCodes === 1) {
        recommended = false;
        confidence  = 'low';
        reason = `Only 1 binary code column was detected. ENA needs at least 2 (ideally 4+).`;
    } else {
        recommended = false;
        confidence  = 'low';
        reason = `No binary (0/1) code columns were detected. ENA requires presence/absence code columns.`;
    }

    return {
        recommended,
        confidence,
        reason,
        nRows,
        nCols: headers.length,
        codes: codeCols,
        units,
        conversations,
        groups,
        columns,
        suggestedUnits,
        suggestedConversations,
    };
}

export default detectParams;
