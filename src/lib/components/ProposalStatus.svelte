<script lang="ts">
	import { ProposalStatus } from '$lib/types/ProposalCard.t';
	import type { Component } from 'svelte';
	import { ClockOutline, CheckCircleOutline, CloseCircleOutline } from 'flowbite-svelte-icons';

	let { status, showIcon = true } = $props();

	function getStatusColor(status: ProposalStatus): string | null {
		switch (status) {
			case 'Active':
				return 'text-indigo-500 bg-indigo-100';
			case 'Passed':
				return 'text-green-500 bg-green-100';
			case 'Rejected':
				return 'text-red-500 bg-red-100';
			default:
				return null;
		}
	}

	function getStatusIcon(status: ProposalStatus): Component | null {
		switch (status) {
			case 'Active':
				return ClockOutline;
			case 'Passed':
				return CheckCircleOutline;
			case 'Rejected':
				return CloseCircleOutline;
			default:
				return null;
		}
	}
</script>

<div
	class={`m-1 flex flex-row items-center rounded-2xl ${getStatusColor(status)} gap-x-2 px-3 py-1`}
>
	{#if showIcon}
		{@const IconComponent = getStatusIcon(status)}
		<IconComponent size="md" strokeWidth={2} />
	{/if}
	<p class="text-sm font-medium">{status}</p>
</div>
