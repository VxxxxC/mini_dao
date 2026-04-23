<script lang="ts">
	import { afterNavigate } from '$app/navigation';
	import ProposalCard from '$lib/components/ProposalCard.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { fetchProposals } from '$lib/components/FetchProposals.svelte';

	let proposals: ProposalCardInfoType[] = $state<ProposalCardInfoType[]>([]);

	let voteSuccess = $state<boolean>(false);

		$effect(() => {
			let isLoaded = false;

		function refetchProposals(){
			async function fetchData() {
				proposals = await fetchProposals();
			}
			fetchData(); 
		}

		if(!isLoaded && voteSuccess){
			isLoaded = true;
			refetchProposals();
			voteSuccess = false; // reset after refetch
		}
		return () => {
			isLoaded = false; // reset on cleanup
		}
	});

	// NOTE: afterNavigate fires on EVERY navigation to this page (including tab switches),
	// unlike onMount which only fires once. This ensures data is always fresh.
	afterNavigate(async () => {
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
		{#each proposals as proposal (proposal.proposalId)}
			<ProposalCard
				proposalData={proposal}
				bind:refetchData={voteSuccess}
			/>
		{/each}
	</div>
</div>
