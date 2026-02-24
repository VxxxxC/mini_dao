import { CheckCircleOutline } from 'flowbite-svelte-icons';
import type { StatusCardInfo } from '$lib/types/StatusCard.t';
import type { ProposalCardInfo, HomeProposalCardInfo } from '$lib/types/ProposalCard.t';
import { SvelteDate } from 'svelte/reactivity';

export const statusCardInfo: StatusCardInfo = {
	icon: CheckCircleOutline,
	iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-cyan-50 text-cyan-300',
	cardInfo: {
		title: 'Pass Proposals',
		des: '1'
	}
};

export const proposalCardInfo: ProposalCardInfo = {
	title: 'Proposal Title',
	des: 'This is a description of the proposal. It provides an overview of what the proposal is about and its key points.',
	proposer: '0x1234567890abcdef',
	status: 'Active',
	expire: new SvelteDate('2024-12-31'),
	totalVotes: 100,
	voteYes: 70,
	voteNo: 30
};
