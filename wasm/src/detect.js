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

// ── name-hint vocabularies ──────────────────────────────────────────────────────

const UNIT_HINTS  = new Set(['user', 'student', 'participant', 'speaker', 'person',
                             'author', 'subject', 'respondent', 'id', 'name', 'who']);
const CONVO_HINTS = new Set(['group', 'condition', 'session', 'conversation', 'convo',
                             'episode', 'class', 'team', 'day', 'week', 'period',
                             'context', 'case', 'trial', 'horizon']);
// Names implying free text / metadata — never codes/units/conversations.
const EXCLUDE     = new Set(['timestamp', 'time', 'date', 'text', 'utterance',
                             'message', 'content', 'line', 'row', 'index', 'notes']);

// ── column classifiers ──────────────────────────────────────────────────────────

/** A code column: every non-empty value is 0 or 1. */
export function isBinary(rows, col) {
    const vals = new Set(rows.map(r => r[col]).filter(v => v !== '' && v != null));
    return vals.size > 0 && [...vals].every(v => v === '0' || v === '1' || v === 0 || v === 1);
}

/** Score a column as a UNIT-of-analysis candidate (0–1). 0 = not a candidate. */
export function scoreUnit(col, nUnique, nRows) {
    const name = col.toLowerCase();
    if (nUnique < 2 || nUnique > Math.min(nRows * 0.8, 500)) return 0;
    let s = 0.3;
    if ([...UNIT_HINTS].some(h => name.includes(h))) s += 0.5;
    if (nUnique >= 3 && nUnique <= 200) s += 0.2;
    return Math.min(s, 1.0);
}

/** Score a column as a CONVERSATION / horizon (segmentation) candidate (0–1). */
export function scoreConvo(col, nUnique, nRows) {
    const name = col.toLowerCase();
    if (nUnique < 2 || nUnique > Math.min(nRows * 0.5, 300)) return 0;
    let s = 0.2;
    if ([...CONVO_HINTS].some(h => name.includes(h))) s += 0.6;
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
    const unitCands  = [];   // [score, col, nUnique]
    const convoCands = [];
    const columns    = [];

    for (const col of headers) {
        const nameLower = col.toLowerCase();
        const vals      = rows.map(r => r[col]).filter(v => v !== '' && v != null);
        const nUnique   = new Set(vals).size;

        if ([...EXCLUDE].some(h => nameLower.includes(h))) {
            columns.push({ name: col, nUnique, role: 'metadata' });
            continue;
        }

        if (isBinary(rows, col)) {
            codeCols.push(col);
            columns.push({ name: col, nUnique, role: 'code' });
            continue;
        }

        const uScore = scoreUnit(col, nUnique, nRows);
        const cScore = scoreConvo(col, nUnique, nRows);
        if (uScore > 0 || cScore > 0) {
            const role = uScore >= cScore ? 'unit_candidate' : 'conversation_candidate';
            if (uScore > 0) unitCands.push([uScore, col, nUnique]);
            if (cScore > 0) convoCands.push([cScore, col, nUnique]);
            columns.push({ name: col, nUnique, role });
            continue;
        }

        columns.push({ name: col, nUnique, role: 'other' });
    }

    unitCands.sort((a, b) => b[0] - a[0]);
    convoCands.sort((a, b) => b[0] - a[0]);

    const units = unitCands.slice(0, 5).map(([s, c, u]) =>
        ({ column: c, nUnique: u, score: round2(s) }));
    const conversations = convoCands.slice(0, 5).map(([s, c, u]) =>
        ({ column: c, nUnique: u, score: round2(s) }));

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
    };
}

export default detectParams;
