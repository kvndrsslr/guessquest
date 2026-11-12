import type { Choice } from '#lib/app.svelte.js';

/**
 * Person-days estimate: `people` people for `days` days each, i.e.
 * `people * days` total person-days.
 */
export type Estimate = { people: number; days: number };

/**
 * Wire convention: a `Choice.TwoNumbers` pair carries quarter-units
 * (`value * 4` as a `u8`) so 0.25 increments fit the existing two-byte payload.
 * The server treats the pair as opaque bytes and passes it through unchanged.
 */
const QUARTER = 4;
const MIN_PEOPLE = 1;
const MIN_DAYS = 0.25;
/** 255 / 4: the largest value a quarter-unit `u8` slot can carry. */
const MAX = 255 / QUARTER;

/** Encode a human estimate into quarter-unit wire slots, clamping to the `u8` range. */
export function encodeEstimate(people: number, days: number): [number, number] {
	const encodedPeople = Math.min(MAX, Math.max(MIN_PEOPLE, Math.round(people * QUARTER) / QUARTER));
	const encodedDays = Math.min(MAX, Math.max(MIN_DAYS, Math.round(days * QUARTER) / QUARTER));
	return [Math.round(encodedPeople * QUARTER), Math.round(encodedDays * QUARTER)];
}

/** Decode a quarter-unit wire pair back into a human estimate. */
export function decodeEstimate(choice: [number, number]): Estimate {
	return { people: choice[0] / QUARTER, days: choice[1] / QUARTER };
}

/** Render a choice for display: `2×2` for person-days pairs, the raw value otherwise. */
export function formatChoice(choice: Choice): string {
	if (choice === null) {
		return '';
	}
	if (typeof choice === 'number') {
		return String(choice);
	}
	if (typeof choice === 'string') {
		return choice;
	}
	const { people, days } = decodeEstimate(choice);
	// `toFixed(2)` then `Number` trims trailing zeros: 2 → "2", 2.5 → "2.5", 0.25 → "0.25"
	return `${Number(people.toFixed(2))}×${Number(days.toFixed(2))}`;
}
