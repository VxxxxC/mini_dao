<script lang="ts">
	import { Card } from 'flowbite-svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import type { HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';

	let props: HomeProposalCardInfoType[] = $props();

	const options = {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};
</script>

<div>
	{#each props as prop, index}
		<Card
			size="xl"
			shadow="sm"
			horizontal={false}
			class="hover:border-purple-00 h-full w-full items-start justify-between p-2 transition duration-200 ease-in-out"
		>
			<div class="flex w-full flex-row justify-between">
				<div class="flex flex-col justify-between">
					<div>{prop.title}</div>
					<div>{prop.des}</div>
					<!-- FIX: need to fix below date time format-->
					<div>{new Intl.DateTimeFormat('en-US', options).format(prop.expire)}</div>
				</div>
				<div class="flex flex-col justify-between">
					<ProposalStatus status={prop.status} showIcon={false} />
					<div>{prop.totalVotes}</div>
				</div>
			</div>
		</Card>
	{/each}
</div>
