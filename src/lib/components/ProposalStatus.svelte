<script lang="ts">
	import { ProposalStatus } from '$lib/types/ProposalCard.t';
	import type { Component } from 'svelte';
	import { ClockOutline, CheckCircleOutline, CloseCircleOutline } from 'flowbite-svelte-icons';

	let { status, showIcon = true } = $props();

	function getStatusColor(status: ProposalStatus): string | null {
		switch (status) {
			case ProposalStatus.Pending:
				return 'text-yellow-500 bg-yellow-100';
			case ProposalStatus.Active:
				return 'text-indigo-500 bg-indigo-100';
			case ProposalStatus.Canceled:
				return 'text-gray-500 bg-gray-100';
			case ProposalStatus.Defeated:
				return 'text-red-500 bg-red-100';
			case ProposalStatus.Succeeded:
				return 'text-green-500 bg-green-100';
			case ProposalStatus.Queued:
				return 'text-blue-500 bg-blue-100';
			case ProposalStatus.Expired:
				return 'text-orange-500 bg-orange-100';
			case ProposalStatus.Executed:
				return 'text-emerald-500 bg-emerald-100';
			default:
				return null;
		}
	}

	function getStatusIcon(status: ProposalStatus): Component | null {
		switch (status) {
			case ProposalStatus.Pending:
				return ClockOutline;
			case ProposalStatus.Active:
				return ClockOutline;
			case ProposalStatus.Canceled:
				return CloseCircleOutline;
			case ProposalStatus.Defeated:
				return CloseCircleOutline;
			case ProposalStatus.Succeeded:
				return CheckCircleOutline;
			case ProposalStatus.Queued:
				return ClockOutline;
			case ProposalStatus.Expired:
				return ClockOutline;
			case ProposalStatus.Executed:
				return CheckCircleOutline;
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
