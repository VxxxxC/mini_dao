import { render } from 'vitest-browser-svelte';
import { expect, test, describe, vi, beforeEach } from 'vitest';
import { page } from '@vitest/browser/context';
import ProposalCard from '$lib/components/ProposalCard.svelte';
import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';
import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
vi.mock('$lib/components/WalletStore.svelte.ts', () => ({
	walletStatus: { address: '', status: 'disconnected' }
}));

vi.mock('$lib/config/appKitConfig', () => ({
	wagmiConfig: {}
}));

vi.mock('@wagmi/core', () => ({
	writeContract: vi.fn(),
	waitForTransactionReceipt: vi.fn(),
	getTransactionCount: vi.fn()
}));

vi.mock('$lib/config/viem/client', () => ({
	publicClient: { readContract: vi.fn().mockResolvedValue(false) }
}));

vi.mock('$lib/config/contractAddress', () => ({
	Address: { GOVERNANCE: '0xGOV' }
}));

vi.mock('$lib/contracts_abi/MiniDaoGovernance.json', () => ({ default: { abi: [] } }));

// Stub ApexChart — renders nothing; avoids apexcharts headless issues
vi.mock('$lib/components/ApexChart.svelte', () => ({ default: {} }));

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
		render(ProposalCard, { proposalData: makeProposal(), onVoteSuccess: vi.fn() });
		await expect.element(page.getByText('Test Proposal')).toBeInTheDocument();
	});

	test('displays proposal description', async () => {
		render(ProposalCard, { proposalData: makeProposal(), onVoteSuccess: vi.fn() });
		await expect.element(
			page.getByText('This is a test proposal description.')
		).toBeInTheDocument();
	});

	test('displays proposer address', async () => {
		render(ProposalCard, { proposalData: makeProposal(), onVoteSuccess: vi.fn() });
		await expect
			.element(page.getByText('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'))
			.toBeInTheDocument();
	});

	test('displays total vote count', async () => {
		render(ProposalCard, { proposalData: makeProposal({ totalVotes: 42 }), onVoteSuccess: vi.fn() });
		await expect.element(page.getByText('42 votes')).toBeInTheDocument();
	});

	test('renders zero votes without error', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ voteFor: 0, voteAgainst: 0, voteAbstain: 0, totalVotes: 0 }),
			onVoteSuccess: vi.fn()
		});
		await expect.element(page.getByText('0 votes')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Wallet connection state
// ---------------------------------------------------------------------------
describe('ProposalCard – wallet not connected', () => {
	test('shows connect-wallet prompt when wallet is disconnected', async () => {
		render(ProposalCard, { proposalData: makeProposal(), onVoteSuccess: vi.fn() });
		await expect
			.element(page.getByText('Please connect your wallet to vote'))
			.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Countdown badge
// ---------------------------------------------------------------------------
describe('ProposalCard – countdown badge', () => {
	test('shows "Start Voting Now" when startToVote is 0', async () => {
		render(ProposalCard, { proposalData: makeProposal({ startToVote: 0 }), onVoteSuccess: vi.fn() });
		await expect.element(page.getByText('Start Voting Now')).toBeInTheDocument();
	});

	test('shows "Starts in …" badge when startToVote > 0', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 3661 }),
			onVoteSuccess: vi.fn()
		});
		// After onMount sets countdown, badge text updates
		await expect.element(page.getByText(/Starts in/)).toBeInTheDocument();
	});

	test('formats 1 hour correctly', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 3600 }),
			onVoteSuccess: vi.fn()
		});
		await expect.element(page.getByText(/1h/)).toBeInTheDocument();
	});

	test('formats 1 day correctly', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ startToVote: 86400 }),
			onVoteSuccess: vi.fn()
		});
		await expect.element(page.getByText(/1d/)).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Fuzz – edge case prop values
// ---------------------------------------------------------------------------
describe('ProposalCard – fuzz: extreme prop values', () => {
	test('renders with very large vote counts', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ totalVotes: 9999999 }),
			onVoteSuccess: vi.fn()
		});
		await expect.element(page.getByText('9999999 votes')).toBeInTheDocument();
	});

	test('renders with empty title', async () => {
		render(ProposalCard, {
			proposalData: makeProposal({ title: '' }),
			onVoteSuccess: vi.fn()
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
				onVoteSuccess: vi.fn()
			});
			await expect.element(page.getByText('Test Proposal')).toBeInTheDocument();
		}
		expect.assertions(statuses.length);
	});
});
