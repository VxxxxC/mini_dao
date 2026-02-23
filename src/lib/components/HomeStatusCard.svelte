<script lang="ts">
	import { Card } from 'flowbite-svelte';

	let { icon: IconProp, iconClass } = $props();
</script>

<div>
	<Card
		class="mx-2 grid grid-cols-4 items-start p-2 transition duration-300 ease-in hover:border-indigo-300 hover:shadow-xl/30 hover:shadow-indigo-600/40"
	>
		<div class="col-span-1">
			<IconProp class={iconClass} />
		</div>
		<div class="col-span-2 flex flex-col items-start justify-between py-2">
			<div class="text-sm font-normal text-gray-500">Pass Proposal</div>

			<div class="text-lg font-bold text-gray-900">999</div>
		</div>
		<div class="col-span-1"></div>
	</Card>
</div>
