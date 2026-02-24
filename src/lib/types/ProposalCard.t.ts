import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfoType {
	title: string;
	des: string;
	proposer: string;
	status: string;
	expire: SvelteDate;
	totalVotes: number;
	voteYes: number;
	voteNo: number;
}

export type HomeProposalCardInfoType = Omit<
	ProposalCardInfoType,
	'proposer' | 'voteYes' | 'voteNo'
>;
