<script lang="ts">
	import ApexChart from '$lib/components/ApexChart.svelte';
	import { Card } from 'flowbite-svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

	let props: ProposalCardInfoType[] = $props();

	const options = {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};
</script>

<div class="flex flex-col items-center space-y-5">
	{#each props as prop, index (index)}
		<Card
			size="xl"
			shadow="sm"
			horizontal={false}
			class="h-full w-full items-start justify-between p-8 transition duration-200 ease-in-out hover:border-purple-400"
		>
			<div class="flex w-full flex-col items-center">
				<div class="flex w-full flex-row items-center justify-between">
					<div class="text-lg font-bold">{prop.title}</div>
					<ProposalStatus status={prop.status} />
				</div>

				<div class="space-y-5 self-start">
					<div class="text-md text-subtl font-light">{prop.des}</div>
					<div class="flex flex-row items-center space-x-2">
						<p class="text-xs text-secondary">Proposer:</p>
						<p class="text-sm font-light text-subtle">
							{prop.proposer}
						</p>
					</div>
				</div>
				<ApexChart {...prop} />
				<!-- FIX: need to fix below date time format-->
				<div class="flex w-full flex-row items-center justify-between">
					<div class="text-xs font-normal text-secondary">
						Ends: {new Intl.DateTimeFormat('en-US', options).format(prop.expire)}
					</div>

					<div class="text-xs font-normal text-secondary">{prop.totalVotes} votes</div>
				</div>
			</div>
			<div class="flex h-12 w-full flex-row justify-between space-x-2">
				<button
					class="w-full rounded-md border border-green-300 bg-green-50 text-green-600 hover:bg-green-100"
					>Vote Yes</button
				>
				<button
					class="w-full rounded-md border border-red-300 bg-red-50 text-red-600 hover:bg-red-100"
					>Vote No</button
				>
			</div>
		</Card>
	{/each}
</div>
