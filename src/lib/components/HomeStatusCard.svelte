<script lang="ts">
	import { Card } from 'flowbite-svelte';
	import type { Component } from 'svelte';

	let props = $props();
</script>

<div>
	<Card class="mx-2 grid grid-cols-4 items-center gap-x-2">
		<div class="col-span-1">
			<!-- WARN: Below is going to deprecated , need to find another solution -->
			<svelte:component this={props.icon} size={props.iconSize} class={props.iconClass} />
		</div>
		<div class="col-span-2 flex flex-col items-start justify-center">
			<div class="font-normal text-gray-600">upper</div>

			<div class="font-bold">lower</div>
		</div>
		<div class="col-span-1">footer</div>
	</Card>
</div>
