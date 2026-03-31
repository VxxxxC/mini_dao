<script lang="ts">
	import { onMount } from 'svelte';
	import { getPublicClient, readContract } from '@wagmi/core';
	import ProposalCard from '$lib/components/ProposalCard.svelte';
	import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { fetchProposals } from '$lib/components/FetchProposals.svelte';

	let proposals: ProposalCardInfoType[] = $state<ProposalCardInfoType[]>([]);

	onMount(async () => {
		proposals = await fetchProposals();
	});
</script>

<div class="grid w-full space-y-5">
	<div class="flex flex-col items-start space-y-5">
		<p class="text-3xl font-bold text-gray-900">Proposals</p>
		<p class="text-sm font-normal text-gray-500">
			View all proposals and participate in voting decisions
		</p>
	</div>

	<div class="flex flex-col space-y-5">
		{#each proposals as proposal, index (index)}
			<ProposalCard proposalData={proposal} onVoteSuccess={async () => await fetchProposals()} />
		{/each}
	</div>
</div>
