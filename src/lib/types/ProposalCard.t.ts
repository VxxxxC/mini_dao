import type { SvelteDate } from 'svelte/reactivity';

export interface ProposalCardInfoType {
	title: string;
	description: string;
	proposerId?: `0x${string}`;
	proposer: `0x${string}`;
	state: ProposalStatus;
	ipfsCid: string;
	expire: SvelteDate;
	totalVotes?: number;
	voteYes?: number;
	voteNo?: number;
}

export type HomeProposalCardInfoType = Omit<
	ProposalCardInfoType,
	'proposer' | 'voteYes' | 'voteNo'
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
