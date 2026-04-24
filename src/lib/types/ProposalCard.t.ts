import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfoType {
	title: string;
	description: string;
	proposalId: bigint;
	proposer: `0x${string}`;
	state: ProposalStatusEnum;
	ipfsCid: string;
	expire: number;
	startToVote?: number;
	totalVotes?: number;
	voteFor?: number;
	voteAgainst?: number;
	voteAbstain?: number;
}

export type HomeProposalCardInfoType = Omit<
	ProposalCardInfoType,
	'proposer' | 'voteFor' | 'voteAgainst' | 'voteAbstain'
>;

export enum ProposalStatusEnum {
	"Pending",
	"Active",
	"Canceled",
	"Defeated",
	"Succeeded",
	"Queued",
	"Expired",
	"Executed"
}

export type voteType = {
		againstVotes: number;
		forVotes: number;
		abstainVotes: number;
	};
// 0 = Against, 1 = For, 2 = Abstain