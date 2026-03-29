import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfoType {
	title: string;
	description: string;
	proposalId: bigint;
	proposer: `0x${string}`;
	state: ProposalStatus;
	ipfsCid: string;
	expire: number;
	totalVotes?: number;
	voteFor?: number;
	voteAgainst?: number;
	voteAbstain?: number;
} // 0 = Against, 1 = For, 2 = Abstain

export type HomeProposalCardInfoType = Omit<
	ProposalCardInfoType,
	'proposer' | 'voteFor' | 'voteAgainst' | 'voteAbstain'
>;

export enum ProposalStatus {
	"Pending",
	"Active",
	"Canceled",
	"Defeated",
	"Succeeded",
	"Queued",
	"Expired",
	"Executed"
}
