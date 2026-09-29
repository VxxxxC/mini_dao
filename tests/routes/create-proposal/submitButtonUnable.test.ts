/**
 * Server-side unit tests for the submitButtonUnable() logic in
 * src/routes/create-proposal/+page.svelte.
 *
 * The function is re-implemented here as a pure function to enable fast,
 * dependency-free unit tests and fuzz coverage.
 */

import { describe, test, expect } from 'vitest';

// ---------------------------------------------------------------------------
// Mirror of the function from +page.svelte — keep in sync manually.
// ---------------------------------------------------------------------------
function submitButtonUnable(
	connectStatus: string,
	proposalTitle: string,
	proposalDescription: string
): boolean {
	if (connectStatus === 'connected') {
		if (proposalTitle.trim().length >= 5 && proposalDescription.trim().length >= 20) return true;
		else return false;
	}
	return false;
}

const VALID_TITLE = 'A valid title';
const VALID_DESC = 'This description is definitely long enough.';

// ---------------------------------------------------------------------------
// Wallet connection guard
// ---------------------------------------------------------------------------
describe('submitButtonUnable – connection guard', () => {
	test('returns false when wallet is disconnected', () => {
		expect(submitButtonUnable('disconnected', VALID_TITLE, VALID_DESC)).toBe(false);
	});

	test('returns false when status is empty string', () => {
		expect(submitButtonUnable('', VALID_TITLE, VALID_DESC)).toBe(false);
	});
});

// ---------------------------------------------------------------------------
// Title validation
// ---------------------------------------------------------------------------
describe('submitButtonUnable – title length', () => {
	test('returns false for title shorter than 5 chars', () => {
		expect(submitButtonUnable('connected', 'hi', VALID_DESC)).toBe(false);
	});

	test('returns false for title of exactly 4 chars', () => {
		expect(submitButtonUnable('connected', 'Test', VALID_DESC)).toBe(false);
	});

	test('returns true for title of exactly 5 chars', () => {
		expect(submitButtonUnable('connected', 'Hello', VALID_DESC)).toBe(true);
	});

	test('returns false when title is only whitespace', () => {
		expect(submitButtonUnable('connected', '     ', VALID_DESC)).toBe(false);
	});
});

// ---------------------------------------------------------------------------
// Description validation
// ---------------------------------------------------------------------------
describe('submitButtonUnable – description length', () => {
	test('returns false for description shorter than 20 chars', () => {
		expect(submitButtonUnable('connected', VALID_TITLE, 'Too short')).toBe(false);
	});

	test('returns false for description of exactly 19 chars', () => {
		expect(submitButtonUnable('connected', VALID_TITLE, '1234567890123456789')).toBe(false);
	});

	test('returns true for description of exactly 20 chars', () => {
		expect(submitButtonUnable('connected', VALID_TITLE, '12345678901234567890')).toBe(true);
	});

	test('returns false when description is only whitespace', () => {
		expect(submitButtonUnable('connected', VALID_TITLE, ' '.repeat(25))).toBe(false);
	});
});

// ---------------------------------------------------------------------------
// Fuzz – boundary sweep for title length 0..10
// ---------------------------------------------------------------------------
describe('submitButtonUnable – fuzz: title boundary sweep', () => {
	for (let n = 0; n <= 10; n++) {
		const expected = n >= 5;
		test(`title length ${n} → ${expected}`, () => {
			expect(submitButtonUnable('connected', 'a'.repeat(n), VALID_DESC)).toBe(expected);
		});
	}
});

// ---------------------------------------------------------------------------
// Fuzz – boundary sweep for description length 0..25
// ---------------------------------------------------------------------------
describe('submitButtonUnable – fuzz: description boundary sweep', () => {
	for (let n = 0; n <= 25; n++) {
		const expected = n >= 20;
		test(`description length ${n} → ${expected}`, () => {
			expect(submitButtonUnable('connected', VALID_TITLE, 'b'.repeat(n))).toBe(expected);
		});
	}
});

// ---------------------------------------------------------------------------
// Fuzz – unicode / special characters
// ---------------------------------------------------------------------------
describe('submitButtonUnable – fuzz: unicode inputs', () => {
	const cases: Array<{ title: string; desc: string }> = [
		{ title: '你好世界！', desc: VALID_DESC },
		{ title: '😀😀😀😀😀', desc: VALID_DESC },
		{ title: VALID_TITLE, desc: '这是一个足够长的提案描述内容。' }
	];

	for (const { title, desc } of cases) {
		test(`does not crash for title="${title.slice(0, 10)}" desc="${desc.slice(0, 10)}..."`, () => {
			const result = submitButtonUnable('connected', title, desc);
			expect(typeof result).toBe('boolean');
		});
	}
});
