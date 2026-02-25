import type { ProposalCardInfoType, HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';
import { ProposalStatus } from '$lib/types/ProposalCard.t';
import { SvelteDate } from 'svelte/reactivity';

export const proposalCardInfo: ProposalCardInfoType = {
	title: 'Proposal Title',
	des: 'This is a description of the proposal. It provides an overview of what the proposal is about and its key points.',
	proposer: '0x1234567890abcdef',
	status: ProposalStatus.Active,
	expire: new SvelteDate('2024-12-31'),
	totalVotes: 100,
	voteYes: 70,
	voteNo: 30
};
