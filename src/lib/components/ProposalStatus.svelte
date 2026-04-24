<script lang="ts">
	import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';
	import type { Component } from 'svelte';
	import { ClockOutline, CheckCircleOutline, CloseCircleOutline } from 'flowbite-svelte-icons';

	let { status, showIcon = true } = $props();

	function getStatusColor(status: ProposalStatusEnum): string | null {
		switch (status) {
			case ProposalStatusEnum.Pending:
				return 'text-yellow-500 bg-yellow-100';
			case ProposalStatusEnum.Active:
				return 'text-indigo-500 bg-indigo-100';
			case ProposalStatusEnum.Canceled:
				return 'text-gray-500 bg-gray-100';
			case ProposalStatusEnum.Defeated:
				return 'text-red-500 bg-red-100';
			case ProposalStatusEnum.Succeeded:
				return 'text-green-500 bg-green-100';
			case ProposalStatusEnum.Queued:
				return 'text-blue-500 bg-blue-100';
			case ProposalStatusEnum.Expired:
				return 'text-orange-500 bg-orange-100';
			case ProposalStatusEnum.Executed:
				return 'text-emerald-500 bg-emerald-100';
			default:
				return null;
		}
	}

	function getStatusIcon(status: ProposalStatusEnum): Component | null {
		switch (status) {
			case ProposalStatusEnum.Pending:
				return ClockOutline;
			case ProposalStatusEnum.Active:
				return ClockOutline;
			case ProposalStatusEnum.Canceled:
				return CloseCircleOutline;
			case ProposalStatusEnum.Defeated:
				return CloseCircleOutline;
			case ProposalStatusEnum.Succeeded:
				return CheckCircleOutline;
			case ProposalStatusEnum.Queued:
				return ClockOutline;
			case ProposalStatusEnum.Expired:
				return ClockOutline;
			case ProposalStatusEnum.Executed:
				return CheckCircleOutline;
			default:
				return null;
		}
	}

	function getStatusText(status: ProposalStatusEnum): string {
		switch (status) {
			case ProposalStatusEnum.Pending:
				return 'Pending';
			case ProposalStatusEnum.Active:
				return 'Active';
			case ProposalStatusEnum.Canceled:
				return 'Canceled';
			case ProposalStatusEnum.Defeated:
				return 'Defeated';
			case ProposalStatusEnum.Succeeded:
				return 'Succeeded';
			case ProposalStatusEnum.Queued:
				return 'Queued';
			case ProposalStatusEnum.Expired:
				return 'Expired';
			case ProposalStatusEnum.Executed:
				return 'Executed';
			default:
				return 'Unknown';
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
	<p class="text-sm font-medium">{getStatusText(status)}</p>
</div>
