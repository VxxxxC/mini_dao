import type { ProposalCardInfoType, HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';
import { ProposalStatus } from '$lib/types/ProposalCard.t';
import { SvelteDate } from 'svelte/reactivity';

export const firstProposalCardInfo: ProposalCardInfoType = {
	title: 'Proposal Title',
	des: 'This is a description of the proposal. It provides an overview of what the proposal is about and its key points.',
	proposer: '0x1234567890abcdef',
	status: ProposalStatus.Active,
	expire: new SvelteDate('2024-12-31'),
	totalVotes: 500,
	voteYes: 170,
	voteNo: 280
};

export const secondProposalCardInfo: ProposalCardInfoType = {
	title: 'Another Proposal',
	des: 'This proposal focuses on a different aspect of the project, aiming to improve user experience and engagement.',
	proposer: '0xabcdef1234567890',
	status: ProposalStatus.Passed,
	expire: new SvelteDate('2025-01-15'),
	totalVotes: 50,
	voteYes: 25,
	voteNo: 25
};
