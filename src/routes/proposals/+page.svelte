<script lang="ts">
	import ProposalCard from '$lib/components/ProposalCard.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { firstProposalCardInfo, secondProposalCardInfo } from '$lib/mock_data';

	const proposalCardInfoProps: ProposalCardInfoType[] = [
		firstProposalCardInfo,
		secondProposalCardInfo
	];
</script>

<div class="grid w-full space-y-5">
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
