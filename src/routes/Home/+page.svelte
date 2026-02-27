<script lang="ts">
	import { page } from '$app/state';
	import HomeStatusCard from '$lib/components/HomeStatusCard.svelte';
	import HomeProposalCard from '$lib/components/HomeProposalCard.svelte';
	import { Card } from 'flowbite-svelte';
	import type { StatusCardInfoType } from '$lib/types/StatusCard.t';
	import type { HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { proposalCardInfo } from '$lib/mock_data';
	import { ArrowRightOutline } from 'flowbite-svelte-icons';
	import {
		communityMemebers,
		activeProposal,
		passedProposal,
		totalVotes
	} from '$lib/stores/StatusCard';

	let activeUrl = $derived(page.url.pathname);

	const statusCardInfoProps: StatusCardInfoType[] = [
		communityMemebers,
		activeProposal,
		passedProposal,
		totalVotes
	];
	const proposalCardInfoProps: HomeProposalCardInfoType[] = [proposalCardInfo];
</script>

<div class="relative top-32 my-2">
	<div class="grid justify-center gap-y-5">
		<!-- NOTE: UPPER SECTION -->
		<div class="flex flex-col items-center gap-y-5">
			<p class="text-3xl font-black">Community Governance Platform</p>
			<p class="text-sm font-normal text-gray-500">
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
						<p class="text-xl font-bold">Active Proposals</p>
						<p class="text-sm font-normal text-gray-600">View and participate in voting</p>
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
					<HomeProposalCard {...proposalCardInfoProps} />
				</div>
			</Card>
		</div>

		<!-- NOTE: LOWER SECTION -->
		<div class="font-black">lower column</div>
	</div>
</div>
