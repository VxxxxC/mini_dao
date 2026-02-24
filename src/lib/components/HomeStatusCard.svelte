<script lang="ts">
	import type { StatusCardInfoType } from '$lib/types/StatusCard.t';
	import { Card } from 'flowbite-svelte';

	let props: StatusCardInfoType[] = $props();
</script>

<div>
	{#each props as prop, index}
		<Card
			size="md"
			shadow="sm"
			horizontal={true}
			class="mx-2 grid grid-cols-4 items-start p-2 transition duration-300 ease-in hover:border-indigo-300 hover:shadow-xl/30 hover:shadow-indigo-600/40"
		>
			<div class="col-span-1">
				{#if prop.icon}
					{@const IconProp = prop.icon}
					<IconProp class={prop.iconClass} />
				{/if}
			</div>
			<div class="col-span-2 flex flex-col items-start justify-between py-2">
				<div class="text-sm font-normal text-gray-500">{prop.cardInfo.title}</div>

				<div class="text-lg font-bold text-gray-900">{prop.cardInfo.des}</div>
			</div>
			<div class="col-span-1"></div>
		</Card>
	{/each}
</div>
