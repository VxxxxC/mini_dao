/**
 * Server-side unit tests for FetchProposals.svelte.ts
 * Runs under the "server" vitest project (environment: node).
 */

import { describe, test, expect, vi, beforeEach } from 'vitest';

// ---------------------------------------------------------------------------
// Mocks — hoisted before the module under test is imported
// ---------------------------------------------------------------------------
vi.mock('$lib/config/viem/client', () => ({
	publicClient: {
		getContractEvents: vi.fn(),
		readContract: vi.fn()
	}
}));

vi.mock('$lib/config/contractAddress', () => ({
	Address: { GOVERNANCE: '0xGOVERNANCE' }
}));

vi.mock('$lib/contracts_abi/MiniDaoGovernance.json', () => ({
	default: { abi: [] }
}));

// ---------------------------------------------------------------------------
// Imports (after mocks)
// ---------------------------------------------------------------------------
import { fetchProposals } from '$lib/components/FetchProposals.svelte';
import { publicClient } from '$lib/config/viem/client';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const MOCK_CID = 'QmTestCid';
const MOCK_PROPOSAL_ID = 42n;

function mockLog(overrides: { proposalId?: bigint; description?: string } = {}) {
	return {
		args: {
			proposalId: overrides.proposalId ?? MOCK_PROPOSAL_ID,
			description: overrides.description ?? MOCK_CID
		}
	};
}

function setupChainMocks(voteResult = [10n, 20n, 5n]) {
	(publicClient.getContractEvents as ReturnType<typeof vi.fn>).mockResolvedValue([mockLog()]);
	(publicClient.readContract as ReturnType<typeof vi.fn>).mockImplementation(({ functionName }) => {
		if (functionName === 'state') return Promise.resolve(1);
		if (functionName === 'countdownStartVoting') return Promise.resolve(0n);
		if (functionName === 'proposalVotes') return Promise.resolve(voteResult);
		return Promise.resolve(null);
	});
}

function setupIpfsFetch(ok: boolean, data?: object) {
	global.fetch = vi.fn().mockResolvedValue({
		ok,
		json: () =>
			Promise.resolve(
				data ?? {
					proposalTitle: 'Test Proposal',
					proposalDescription: 'A proposal description.',
					proposerAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
					timestamp: '2025-01-01T00:00:00.000Z'
				}
			)
	});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
beforeEach(() => {
	vi.clearAllMocks();
});

describe('fetchProposals – happy path', () => {
	test('returns one formatted proposal on success', async () => {
		setupChainMocks();
		setupIpfsFetch(true);

		const results = await fetchProposals();

		expect(results).toHaveLength(1);
		expect(results[0].proposalId).toBe(MOCK_PROPOSAL_ID);
		expect(results[0].title).toBe('Test Proposal');
		expect(results[0].state).toBe(1);
	});

	test('maps vote weights: index 0 = against, 1 = for, 2 = abstain', async () => {
		setupChainMocks([5n, 15n, 3n]);
		setupIpfsFetch(true);

		const [p] = await fetchProposals();
		expect(p.voteAgainst).toBe(5);
		expect(p.voteFor).toBe(15);
		expect(p.voteAbstain).toBe(3);
		expect(p.totalVotes).toBe(23);
	});

	test('reverses proposals order (newest last event → first result)', async () => {
		const id1 = 1n;
		const id2 = 2n;
		(publicClient.getContractEvents as ReturnType<typeof vi.fn>).mockResolvedValue([
			mockLog({ proposalId: id1 }),
			mockLog({ proposalId: id2 })
		]);
		(publicClient.readContract as ReturnType<typeof vi.fn>).mockResolvedValue(0n);
		setupIpfsFetch(true);

		const results = await fetchProposals();
		expect(results[0].proposalId).toBe(id2);
		expect(results[1].proposalId).toBe(id1);
	});

	test('returns [] when no ProposalCreated events exist', async () => {
		(publicClient.getContractEvents as ReturnType<typeof vi.fn>).mockResolvedValue([]);
		const results = await fetchProposals();
		expect(results).toEqual([]);
	});
});

describe('fetchProposals – IPFS failure fallback', () => {
	test('uses fallback title when IPFS returns non-OK response', async () => {
		setupChainMocks();
		setupIpfsFetch(false);

		const [p] = await fetchProposals();
		expect(p.title).toContain('⚠️');
		expect(p.description).toContain('IPFS');
	});

	test('uses fallback title when IPFS throws a network error', async () => {
		setupChainMocks();
		global.fetch = vi.fn().mockRejectedValue(new Error('Network error'));

		const [p] = await fetchProposals();
		expect(p.title).toContain('⚠️');
	});
});

describe('fetchProposals – chain failure', () => {
	test('returns [] when getContractEvents throws', async () => {
		(publicClient.getContractEvents as ReturnType<typeof vi.fn>).mockRejectedValue(
			new Error('RPC error')
		);

		const results = await fetchProposals();
		expect(results).toEqual([]);
	});
});

// ---------------------------------------------------------------------------
// Fuzz – extreme bigint values as proposalId
// ---------------------------------------------------------------------------
describe('fetchProposals – fuzz: extreme proposalId values', () => {
	const extremeIds = [0n, 1n, BigInt(Number.MAX_SAFE_INTEGER), 2n ** 64n - 1n];

	for (const id of extremeIds) {
		test(`handles proposalId = ${id}`, async () => {
			(publicClient.getContractEvents as ReturnType<typeof vi.fn>).mockResolvedValue([
				mockLog({ proposalId: id })
			]);
			(publicClient.readContract as ReturnType<typeof vi.fn>).mockResolvedValue(0n);
			setupIpfsFetch(true);

			const results = await fetchProposals();
			expect(results).toHaveLength(1);
			expect(results[0].proposalId).toBe(id);
		});
	}
});
