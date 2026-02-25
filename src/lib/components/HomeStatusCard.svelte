<script lang="ts">
	import type { StatusCardInfoType } from '$lib/types/StatusCard.t';
	import { Card } from 'flowbite-svelte';

	let props: StatusCardInfoType[] = $props();
</script>

<div class="grid grid-cols-1 items-start justify-center gap-4 md:grid-cols-2 lg:grid-cols-4">
	{#each props as prop, index}
		<Card
			size="md"
			shadow="sm"
			horizontal={true}
			class="mx-2 flex flex-row flex-wrap items-start gap-x-4 p-2 transition duration-300 ease-in hover:border-indigo-300 hover:shadow-xl/30 hover:shadow-indigo-600/40"
		>
			<div>
				{#if prop.icon}
					{@const IconProp = prop.icon}
					<IconProp class={prop.iconClass} />
				{/if}
			</div>
			<div class="flex flex-col items-start justify-between py-2">
				<div class="text-sm font-normal text-subtle">{prop.cardInfo.title}</div>

				<div class="text-lg font-bold text-gray-900">{prop.cardInfo.des}</div>
			</div>
		</Card>
	{/each}
</div>
