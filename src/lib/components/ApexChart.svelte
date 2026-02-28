<script lang="ts">
	import { onMount } from 'svelte';
	import type { ApexOptions } from 'apexcharts';
	import { Chart } from '@flowbite-svelte-plugins/chart';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

	const prop: ProposalCardInfoType = $props();

	type voteChartType = {
		name: string;
		color: string;
		data: number[];
	};

	let voteYes: voteChartType = {
		name: 'Yes',
		color: 'green',
		data: [prop.voteYes]
	};
	let voteNo: voteChartType = {
		name: 'No',
		color: 'red',
		data: [prop.voteNo]
	};

	const chartOptions: ApexOptions = {
		series: [voteYes, voteNo],

		labels: [prop.title],

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
			width: 1,
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
	};
</script>

<div class="w-full">
	<Chart options={chartOptions} />
</div>
