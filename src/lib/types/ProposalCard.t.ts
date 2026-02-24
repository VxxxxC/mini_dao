import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfo {
	title: string;
	des: string;
	proposer: string;
	status: string;
	expire: SvelteDate;
	totalVotes: number;
	voteYes: number;
	voteNo: number;
}

export type HomeProposalCardInfo = Omit<ProposalCardInfo, 'proposer' | 'voteYes' | 'voteNo'>;
