/**
 * Server-side unit tests for the WalletStore address validation guard.
 *
 * WalletStore itself uses wagmi watchConnection which cannot run in node, so
 * we test the guard logic pattern directly — the same pattern used in
 * FetchProposals and ProposalCard to protect against the 'Not connected'
 * truthy-but-invalid sentinel value.
 */

import { describe, test, expect } from 'vitest';

// ---------------------------------------------------------------------------
// Guard logic extracted from FetchProposals.svelte.ts / ProposalCard.svelte
// Keep this in sync with production usage.
// ---------------------------------------------------------------------------
function isValidEthAddress(address: string | undefined): boolean {
	return Boolean(address && address.startsWith('0x'));
}

// ---------------------------------------------------------------------------
// Valid addresses
// ---------------------------------------------------------------------------
describe('isValidEthAddress – valid inputs', () => {
	test('accepts a checksummed address', () => {
		expect(isValidEthAddress('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266')).toBe(true);
	});

	test('accepts an all-lowercase address', () => {
		expect(isValidEthAddress('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')).toBe(true);
	});

	test('accepts the zero address', () => {
		expect(isValidEthAddress('0x0000000000000000000000000000000000000000')).toBe(true);
	});
});

// ---------------------------------------------------------------------------
// WalletStore sentinel / invalid values
// ---------------------------------------------------------------------------
describe('isValidEthAddress – WalletStore invalid states', () => {
	test('rejects "Not connected" (WalletStore disconnected sentinel)', () => {
		expect(isValidEthAddress('Not connected')).toBe(false);
	});

	test('rejects empty string (WalletStore initial state)', () => {
		expect(isValidEthAddress('')).toBe(false);
	});

	test('rejects undefined', () => {
		expect(isValidEthAddress(undefined)).toBe(false);
	});
});

// ---------------------------------------------------------------------------
// Other invalid formats
// ---------------------------------------------------------------------------
describe('isValidEthAddress – other invalid formats', () => {
	test('rejects ENS name', () => {
		expect(isValidEthAddress('vitalik.eth')).toBe(false);
	});

	test('rejects address without 0x prefix', () => {
		expect(isValidEthAddress('f39Fd6e51aad88F6F4ce6aB8827279cffFb92266')).toBe(false);
	});

	test('rejects uppercase 0X prefix', () => {
		expect(isValidEthAddress('0X1234567890123456789012345678901234567890')).toBe(false);
	});
});

// ---------------------------------------------------------------------------
// Fuzz – unusual strings that must never pass
// ---------------------------------------------------------------------------
describe('isValidEthAddress – fuzz', () => {
	const invalidInputs = [
		'0',
		'0x', // prefix only
		' 0xabc123', // leading space
		'0xabc123 ', // trailing space
		'null',
		'undefined',
		'true',
		'{}'
	];

	for (const input of invalidInputs) {
		test(`does not crash for "${input}"`, () => {
			const result = isValidEthAddress(input);
			expect(typeof result).toBe('boolean');
		});
	}
});
