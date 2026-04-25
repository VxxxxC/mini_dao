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

<div class="flew flex-col items-center space-y-5">
	{#each props as prop, index (index)}
		<Card
			size="xl"
			shadow="sm"
			horizontal={false}
			class="h-full w-full items-start justify-between p-8 transition duration-200 ease-in-out hover:border-purple-400"
		>
			<div class="flex w-full flex-row justify-between">
				<div class="flex flex-col items-start justify-between gap-y-5">
					<div class="text-lg font-bold dark:text-white">{prop.title}</div>
					<div class="text-md font-normal text-subtle">{prop.description}</div>
					<!-- FIX: need to fix below date time format-->
					<div class="text-xs font-normal text-secondary">
						Ends: {new Intl.DateTimeFormat('en-US', options).format(prop.expire)}
					</div>
				</div>
				<div class="flex flex-col items-center justify-between">
					<ProposalStatus status={prop.state} showIcon={false} />
					<div class="text-xs font-normal text-secondary">{prop.totalVotes} votes</div>
				</div>
			</div>
		</Card>
	{/each}
</div>
