import { describe, expect, it } from 'vitest';
import { decodeEstimate, encodeEstimate, formatChoice } from '../src/lib/estimation.js';

describe('encodeEstimate', () => {
	it('encodes whole estimates as quarter-units', () => {
		expect(encodeEstimate(2, 2)).toEqual([8, 8]);
	});

	it('encodes the smallest days value as one quarter-unit', () => {
		expect(encodeEstimate(1, 0.25)).toEqual([4, 1]);
	});

	it('rounds to the nearest quarter', () => {
		expect(encodeEstimate(1, 0.3)).toEqual([4, 1]);
	});

	it('clamps zero to the minimum estimate', () => {
		expect(encodeEstimate(0, 0)).toEqual([4, 1]);
	});

	it('clamps above the u8 ceiling', () => {
		expect(encodeEstimate(999, 999)).toEqual([255, 255]);
	});
});

describe('decodeEstimate', () => {
	it('decodes quarter-units back to whole estimates', () => {
		expect(decodeEstimate([8, 8])).toEqual({ people: 2, days: 2 });
	});

	it('decodes a single quarter-unit day', () => {
		expect(decodeEstimate([4, 1])).toEqual({ people: 1, days: 0.25 });
	});
});

describe('formatChoice', () => {
	it('formats a person-days pair as people×days', () => {
		expect(formatChoice([8, 8])).toBe('2×2');
	});

	it('formats fractional days without trailing zeros', () => {
		expect(formatChoice([4, 1])).toBe('1×0.25');
	});

	it('formats story point numbers', () => {
		expect(formatChoice(13)).toBe('13');
	});

	it('passes special card values through', () => {
		expect(formatChoice('∞')).toBe('∞');
	});

	it('formats an empty choice as an empty string', () => {
		expect(formatChoice(null)).toBe('');
	});
});
