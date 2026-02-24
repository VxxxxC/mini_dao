<script lang="ts">
	import { Card } from 'flowbite-svelte';
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
			class="h-full w-full items-start justify-between p-2 transition duration-300 ease-in hover:border-indigo-300 hover:shadow-xl/30 hover:shadow-indigo-600/40"
		>
			<div class="flex w-full flex-row justify-between">
				<div class="flex flex-col justify-between">
					<div>{prop.title}</div>
					<div>{prop.des}</div>
					<!-- FIX: need to fix below date time format-->
					<div>{new Intl.DateTimeFormat('en-US', options).format(prop.expire)}</div>
				</div>
				<div class="flex flex-col justify-between">
					<div>{prop.status}</div>
					<div>{prop.totalVotes}</div>
				</div>
			</div>
		</Card>
	{/each}
</div>
