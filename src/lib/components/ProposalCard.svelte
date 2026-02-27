<script lang="ts">
	import { onMount } from 'svelte';
	import type { ApexOptions } from 'apexcharts';
	import { Chart } from '@flowbite-svelte-plugins/chart';
	import { Card } from 'flowbite-svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

	let props: ProposalCardInfoType[] = $props();

	const options = {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};

	type voteChartType = {
		name: string;
		color: string;
		data: number[];
	};

	let voteYes: voteChartType = {
		name: 'Yes',
		color: 'green',
		data: []
	};
	let voteNo: voteChartType = {
		name: 'No',
		color: 'red',
		data: []
	};

	function getChartData() {
		props.forEach((item) => {
			voteYes.data.push(item.voteYes);
			voteNo.data.push(item.voteNo);
		});
	}

	onMount(() => {
		getChartData();
	});

	const chartOptions: ApexOptions = {
		series: [voteYes, voteNo],
		chart: {
			type: 'bar',
			height: 200,
			toolbar: {
				show: false
			},
			stacked: true,
			stackType: '100%',
			sparkline: {
				enabled: true
			}
		},
		plotOptions: {
			bar: {
				horizontal: true
			}
		}
	};
</script>

<div>
	{#each props as prop, index}
		<Card
			size="xl"
			shadow="sm"
			horizontal={false}
			class="h-full w-full items-start justify-between p-8 transition duration-200 ease-in-out hover:border-purple-400"
		>
			<div class="flex w-full flex-row justify-between">
				<div class="flex flex-col items-start justify-between gap-y-5">
					<div class="text-lg font-bold">{prop.title}</div>
					<div class="text-md text-subtl font-normal">{prop.des}</div>
					<div class="flex flex-row items-center space-x-2">
						<p class="text-xs text-secondary">Proposer:</p>
						<p class="text-sm font-medium text-subtle">
							{prop.proposer}
						</p>
					</div>
					<Chart options={chartOptions} />
					<!-- FIX: need to fix below date time format-->
					<div class="text-xs font-normal text-secondary">
						Ends: {new Intl.DateTimeFormat('en-US', options).format(prop.expire)}
					</div>
				</div>
				<div class="flex flex-col items-center justify-between">
					<ProposalStatus status={prop.status} showIcon={false} />
					<div class="text-xs font-normal text-secondary">{prop.totalVotes} votes</div>
				</div>
			</div>
		</Card>
	{/each}
</div>
