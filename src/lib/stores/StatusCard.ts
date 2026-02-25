import { CheckCircleOutline } from 'flowbite-svelte-icons';
import type { StatusCardInfoType } from '$lib/types/StatusCard.t';

export const communityMemebers: StatusCardInfoType = {
	icon: CheckCircleOutline,
	iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-indigo-50 text-indigo-300',
	cardInfo: {
		title: 'Pass Proposals',
		des: '999'
	}
};
export const activeProposal: StatusCardInfoType = {
	icon: CheckCircleOutline,
	iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-purple-50 text-purple-300',
	cardInfo: {
		title: 'Pass Proposals',
		des: '50'
	}
};

export const passedProposal: StatusCardInfoType = {
	icon: CheckCircleOutline,
	iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-green-50 text-green-300',
	cardInfo: {
		title: 'Pass Proposals',
		des: '25'
	}
};

export const totalVotes: StatusCardInfoType = {
	icon: CheckCircleOutline,
	iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-yellow-50 text-yellow-300',
	cardInfo: {
		title: 'Pass Proposals',
		des: '100000'
	}
};
