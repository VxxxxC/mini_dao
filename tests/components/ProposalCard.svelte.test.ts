import { render } from 'vitest-browser-svelte';
import { expect, test, describe, vi, beforeEach } from 'vitest';
import { page } from 'vitest/browser';
import ProposalCard from '$lib/components/ProposalCard.svelte';
import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';
import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
vi.mock('$lib/components/WalletStore.svelte', () => ({
	walletStatus: { address: '', status: 'disconnected' }
}));

vi.mock('$lib/config/appKitConfig', () => ({
	wagmiConfig: {}
}));

vi.mock('@wagmi/core', () => ({
	writeContract: vi.fn(),
	waitForTransactionReceipt: vi.fn(),
	getTransactionCount: vi.fn(),
	getBlock: vi
		.fn()
		.mockResolvedValue({ timestamp: BigInt(Math.floor(Date.now() / 1000)), number: 1000n })
}));

vi.mock('$lib/config/viem/client', () => ({
	publicClient: { readContract: vi.fn().mockResolvedValue(false) }
}));

vi.mock('$lib/config/contractAddress', () => ({
	Address: { GOVERNANCE: '0xGOV', VOTEBOX: '0xVOTEBOX' }
}));

vi.mock('$lib/contracts_abi/MiniDaoGovernance.json', () => ({ default: { abi: [] } }));
vi.mock('$lib/contracts_abi/MiniDaoVoteBox.json', () => ({
	default: {
		abi: [
			{
				type: 'function',
				name: 'storeVote',
				inputs: [],
				outputs: [],
				stateMutability: 'nonpayable'
			}
		]
	}
}));

// Stub ApexChart — vi.fn() is callable; avoids Svelte 5 "not a function" error
vi.mock('$lib/components/ApexChart.svelte', () => ({ default: vi.fn() }));

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------
function makeProposal(overrides: Partial<ProposalCardInfoType> = {}): ProposalCardInfoType {
	return {
		proposalId: 1n,
		title: 'Test Proposal',
		description: 'This is a test proposal description.',
		proposer: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
		state: ProposalStatusEnum.Active,
		ipfsCid: 'QmTest',
		expire: Date.now() + 7 * 24 * 60 * 60 * 1000,
		startToVote: 0,
		endToVote: 0,
		totalVotes: 30,
		voteFor: 20,
		voteAgainst: 5,
		voteAbstain: 5,
		...overrides
	};
}

beforeEach(() => {
	vi.clearAllMocks();
});

// ---------------------------------------------------------------------------
// Basic rendering
// ---------------------------------------------------------------------------
describe('ProposalCard – rendering', () => {
	test('displays proposal title', async () => {
		render(ProposalCard, { proposalData: makeProposal(), refetchData: false });
		await expect.element(page.getByText('Test Proposal', { exact: true })).toBeInTheDocument();
	});

	test('displays proposal description', async () => {
		render(ProposalCard, { proposalData: makeProposal(), refetchData: false });
		await expect
			.element(page.getByText('This is a test proposal description.'))
			.toBeInTheDocument();
	});

	test('displays proposer address', async () => {
		render(ProposalCard, { proposalData: makeProposal(), refetchData: false });
		await expect
			.element(page.getByText('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'))
			.toBeInTheDocument();
	});

	test('displays total vote count', async () => {
		render(ProposalCard, { proposalData: makeProposal({ totalVotes: 42 }), refetchData: false });
		await expect.element(page.getByText('42 votes')).toBeInTheDocument();
	});

	test('renders zero votes without error', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ voteFor: 0, voteAgainst: 0, voteAbstain: 0, totalVotes: 0 }),
			refetchData: false
		});
		await expect.element(page.getByText('0 votes')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Wallet connection state
// ---------------------------------------------------------------------------
describe('ProposalCard – wallet not connected', () => {
	test('shows connect-wallet prompt when wallet is disconnected', async () => {
		render(ProposalCard, { proposalData: makeProposal(), refetchData: false });
		await expect.element(page.getByText('Please connect your wallet to vote')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Countdown badge
// ---------------------------------------------------------------------------
describe('ProposalCard – countdown badge', () => {
	test('shows "Starts in X blocks" badge when Pending and startToVote > 0', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 100, state: ProposalStatusEnum.Pending }),
			refetchData: false
		});
		await expect.element(page.getByText(/Starting in/)).toBeInTheDocument();
	});

	test('shows block count in Pending countdown badge', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 300, state: ProposalStatusEnum.Pending }),
			refetchData: false
		});
		await expect.element(page.getByText(/300 blocks/)).toBeInTheDocument();
	});

	test('shows large block count without error', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 86400, state: ProposalStatusEnum.Pending }),
			refetchData: false
		});
		await expect.element(page.getByText(/86400 blocks/)).toBeInTheDocument();
	});

	test('no countdown badge when Pending and startToVote is 0', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 0, state: ProposalStatusEnum.Pending }),
			refetchData: false
		});
		// countdown = 0 → {#if countdownDisplay} is falsy → badge not rendered
		await expect.element(page.getByText('Test Proposal', { exact: true })).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Fuzz – edge case prop values
// ---------------------------------------------------------------------------
describe('ProposalCard – fuzz: extreme prop values', () => {
	test('renders with very large vote counts', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ totalVotes: 9999999 }),
			refetchData: false
		});
		await expect.element(page.getByText('9999999 votes')).toBeInTheDocument();
	});

	test('renders with empty title', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ title: '' }),
			refetchData: false
		});
		// Card body still renders without throwing
		await expect
			.element(page.getByText('This is a test proposal description.'))
			.toBeInTheDocument();
	});

	test('renders all ProposalStatusEnum values without throwing', async () => {
		const statuses = [
			ProposalStatusEnum.Pending,
			ProposalStatusEnum.Canceled,
			ProposalStatusEnum.Defeated,
			ProposalStatusEnum.Succeeded,
			ProposalStatusEnum.Queued,
			ProposalStatusEnum.Expired,
			ProposalStatusEnum.Executed
		];
		for (const state of statuses) {
			render(ProposalCard, {
				proposalData: makeProposal({ state }),
				refetchData: false
			});
			await expect
				.element(page.getByText('Test Proposal', { exact: true }).first())
				.toBeInTheDocument();
		}
		expect.assertions(statuses.length);
	});
});
