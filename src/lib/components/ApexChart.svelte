<script lang="ts">
	import type { ApexOptions } from 'apexcharts';
	import { Chart } from '@flowbite-svelte-plugins/chart';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import type { voteType } from '$lib/types/ProposalCard.t';

	const { proposalInfo, voteWeight } = $props<{
		proposalInfo: ProposalCardInfoType;
		voteWeight: voteType;
	}>();

	type voteChartType = {
		name: string;
		color: string;
		data: number[];
	};

	// $derived ensures these recompute whenever the voteWeight prop changes
	const voteYes = $derived<voteChartType>({
		name: 'Yes',
		color: 'green',
		data: [voteWeight.forVotes ?? 0]
	});
	const voteNo = $derived<voteChartType>({
		name: 'No',
		color: 'red',
		data: [voteWeight.againstVotes ?? 0]
	});
	const voteAbstain = $derived<voteChartType>({
		name: 'Abstain',
		color: 'gray',
		data: [voteWeight.abstainVotes ?? 0]
	});

	const chartOptions = $derived<ApexOptions>({
		series: [voteYes, voteNo, voteAbstain],

		labels: [proposalInfo.title],

		dataLabels: {
			enabled: true,
			textAnchor: 'middle'
		},

		legend: {
			show: true,
			position: 'bottom',
			horizontalAlign: 'center'
		},

		stroke: {
			width: 0.5,
			colors: ['#fff']
		},

		tooltip: {
			enabled: true,
			followCursor: true
		},

		chart: {
			animations: {
				enabled: true,
				speed: 500,
				animateGradually: {
					enabled: true,
					delay: 150
				},
				dynamicAnimation: {
					enabled: true,
					speed: 350
				}
			},
			type: 'bar',
			height: 100,
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
				horizontal: true,
				barHeight: '30%'
			}
		}
	});
</script>

<div class="w-full">
	<Chart options={chartOptions} />
</div>
