import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfoType {
	title: string;
	des: string;
	proposer: string;
	status: ProposalStatus;
	expire: SvelteDate;
	totalVotes: number;
	voteYes: number;
	voteNo: number;
}

export type HomeProposalCardInfoType = Omit<
	ProposalCardInfoType,
	'proposer' | 'voteYes' | 'voteNo'
>;

export enum ProposalStatus {
	Active = 'Active',
	Passed = 'Passed',
	Rejected = 'Rejected'
}
