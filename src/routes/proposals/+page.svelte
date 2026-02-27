<script lang="ts">
	import ProposalCard from '$lib/components/ProposalCard.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { proposalCardInfo } from '$lib/mock_data';

	const proposalCardInfoProps: ProposalCardInfoType[] = [proposalCardInfo];
</script>

<div class="grid space-y-5">
	<div class="flex flex-col items-start space-y-5">
		<p class="text-3xl font-bold text-gray-900">Proposals</p>
		<p class="text-sm font-normal text-gray-500">
			View all proposals and participate in voting decisions
		</p>
	</div>

	<div>
		<ProposalCard {...proposalCardInfoProps} />
	</div>
</div>
