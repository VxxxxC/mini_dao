<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import HomeStatusCard from '$lib/components/HomeStatusCard.svelte';
	import HomeProposalCard from '$lib/components/HomeProposalCard.svelte';
	import { Card } from 'flowbite-svelte';
	import type { StatusCardInfoType } from '$lib/types/StatusCard.t';
	import type { HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { ArrowRightOutline } from 'flowbite-svelte-icons';
	import { fetchProposals } from '$lib/components/FetchProposals.svelte';
	import DemoBanner from '$lib/components/DemoBanner.svelte';
	import { CheckCircleOutline, ClockOutline } from 'flowbite-svelte-icons';

	let activeUrl = $derived(page.url.pathname);

	const statusCardInfoProps: StatusCardInfoType[] = [
		{
			icon: ClockOutline,
			iconClass:
				'm-2 p-3 h-12 w-12 rounded-xl text-indigo-500 bg-indigo-100 dark:bg-indigo-900 dark:text-indigo-300',
			cardInfo: {
				title: 'Active',
				des: '999'
			}
		},
		{
			icon: CheckCircleOutline,
			iconClass:
				'm-2 p-3 h-12 w-12 rounded-xl text-green-500 bg-green-100 dark:bg-green-900 dark:text-green-300',
			cardInfo: {
				title: 'Succeed / Pass',
				des: '999'
			}
		},
		{
			icon: ClockOutline,
			iconClass:
				'm-2 p-3 h-12 w-12 rounded-xl text-blue-500 bg-blue-100 dark:bg-blue-900 dark:text-blue-300',
			cardInfo: {
				title: 'Queued',
				des: '999'
			}
		},
		{
			icon: CheckCircleOutline,
			iconClass:
				'm-2 p-3 h-12 w-12 rounded-xl text-emerald-500 bg-emerald-100 dark:bg-emerald-900 dark:text-emerald-300',
			cardInfo: {
				title: 'Executed',
				des: '999'
			}
		}
	];
	let proposals: HomeProposalCardInfoType[] = $state<HomeProposalCardInfoType[]>([]);

	onMount(async () => {
		proposals = await fetchProposals();
	});
</script>

<div class="grid justify-center gap-y-5">
	<!-- NOTE: DEMO BANNER -->
	<DemoBanner />

	<!-- NOTE: UPPER SECTION -->
	<div class="flex flex-col items-center gap-y-5">
		<p class="text-3xl font-black dark:text-white">Community Governance Platform</p>
		<p class="text-sm font-normal text-gray-500 dark:text-gray-400">
			Participate in DAO decisions and shape the decentralized future
		</p>

		<div class="min-w-full">
			<HomeStatusCard {...statusCardInfoProps} />
		</div>
	</div>

	<!-- NOTE: CENTER SECTION -->
	<div class="w-full">
		<Card size="xl" shadow="xs" horizontal={false} class="min-w-full items-center gap-y-5 p-8">
			<div class="flex w-full flex-row justify-between">
				<div>
					<p class="text-xl font-bold dark:text-white">Active Proposals</p>
					<p class="text-sm font-normal text-gray-600 dark:text-gray-400">
						View and participate in voting
					</p>
				</div>
				<div class="flex flex-col items-center">
					<a
						href="/proposals"
						class="text-md flex flex-row items-center gap-x-1 rounded-lg px-3 py-1 font-medium text-web3-navbar-active-text hover:bg-web3-navbar-active-bg"
					>
						<p>View All</p>
						<ArrowRightOutline size="sm" strokeWidth={2} />
					</a>
				</div>
			</div>
			<div class="w-full">
				<HomeProposalCard {...proposals} />
			</div>
		</Card>
	</div>

	<!-- NOTE: LOWER SECTION -->
	<!-- <div class="font-black">lower column</div> -->
</div>
