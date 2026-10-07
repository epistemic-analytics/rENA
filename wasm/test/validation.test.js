/**
 * Input validation: inputs that used to produce silently wrong results (or
 * read past the data into WASM heap memory) now raise errors.
 */
import loadENA from '../src/index.js';
import { inferFactorLevels } from '../src/tensor.js';

const ROWS = [
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Role: 'T', D: 1, T: 1, P: 0 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Role: 'S', D: 1, T: 0, P: 1 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U2', Role: 'T', D: 0, T: 1, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U1', Role: 'S', D: 1, T: 1, P: 0 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Role: 'T', D: 0, T: 0, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Role: 'S', D: 1, T: 1, P: 1 },
];
const OPTS = { codes: ['D', 'T', 'P'], units: ['UserName'], conversations: ['Condition', 'GroupName'] };

let ena;
beforeAll(async () => { ena = await loadENA(); });

describe('data columns and code values', () => {
    test('a misspelled code column is an error, not all zeros', () => {
        expect(() => ena.accumulate(ROWS, { ...OPTS, codes: ['D', 'Tx', 'P'] }))
            .toThrow(/codes: column\(s\) not found in the data: Tx/);
    });

    test('a misspelled unit column is an error, not one unit "undefined"', () => {
        expect(() => ena.accumulate(ROWS, { ...OPTS, units: ['User'] })).toThrow(/units: column/);
    });

    test('codes given as a string is an error', () => {
        expect(() => ena.accumulate(ROWS, { ...OPTS, codes: 'DTP' })).toThrow(/codes must be/);
    });

    test('a non-numeric or missing code value is an error, not 0', () => {
        const bad = ROWS.map((r, i) => (i === 2 ? { ...r, T: 'yes' } : r));
        expect(() => ena.accumulate(bad, OPTS)).toThrow(/Code "T" .* row 3/);
        const missing = ROWS.map((r, i) => (i === 4 ? { ...r, P: '' } : r));
        expect(() => ena.accumulate(missing, OPTS)).toThrow(/Code "P"/);
    });

    test('numeric strings and booleans are still accepted', () => {
        const mixed = ROWS.map(r => ({ ...r, D: String(r.D), T: r.T === 1 }));
        expect(() => ena.accumulate(mixed, OPTS)).not.toThrow();
    });

    test('values that join to the same "__" key are not merged', () => {
        const rows = [
            { a: 'x__y', b: 'z', C: 'c1', D: 1, E: 0 },
            { a: 'x', b: 'y__z', C: 'c1', D: 0, E: 1 },
        ];
        expect(() => ena.accumulate(rows, { codes: ['D', 'E'], units: ['a', 'b'], conversations: ['C'] }))
            .toThrow(/both map to "x__y__z"/);
    });
});

describe('statistics wrappers check sizes', () => {
    test('confInts with more units than points is an error, not heap memory', () => {
        expect(() => ena.confInts(new Float64Array([1, 2]), 2000, 1)).toThrow(/expected 2000 × 1/);
    });

    test('outlierInts / compareGroups check every group', () => {
        expect(() => ena.outlierInts(new Float64Array(4), 2, 3)).toThrow(/outlierInts/);
        expect(() => ena.compareGroups(new Float64Array(4), 2, new Float64Array(3), 2, 2))
            .toThrow(/group 2/);
    });

    test('correct sizes still work', () => {
        const r = ena.confInts(new Float64Array([1, 2, 3, 4, 5, 6]), 3, 2);
        expect(r.rows).toBe(2);
    });
});

describe('tensor definitions', () => {
    const ROLE_TENSOR = {
        dims: [2, 2], dimsSender: [0], dimsReceiver: [], dimsMode: [],
        factors: ['Role'], factorLevels: { Role: { T: 0, S: 1 } },
        data: Float64Array.of(1, 1, 2, 2),
    };

    test('a factor level outside its axis is an error', () => {
        const tensor = { ...ROLE_TENSOR, factorLevels: { Role: { T: 0, S: 100000000 } } };
        expect(() => ena.accumulate(ROWS, { ...OPTS, tensor })).toThrow(/outside its axis/);
    });

    test('tensor data length must match dims', () => {
        const tensor = { ...ROLE_TENSOR, data: Float64Array.of(1, 1, 2) };
        expect(() => ena.accumulate(ROWS, { ...OPTS, tensor })).toThrow(/need 4/);
    });

    test('a value with no level is an error, not level 0', () => {
        const tensor = { ...ROLE_TENSOR, factorLevels: { Role: { T: 0 } } };
        expect(() => ena.accumulate(ROWS, { ...OPTS, tensor })).toThrow(/no level for value "S"/);
    });

    test('factor values named like Object.prototype members get their own levels', () => {
        const rows = [{ Role: 'constructor' }, { Role: 'toString' }, { Role: '__proto__' }];
        const levels = inferFactorLevels(rows, ['Role']);
        expect([levels.Role.constructor, levels.Role.toString, levels.Role.__proto__]).toEqual([0, 1, 2]);
    });
});
