<script lang="ts">
	import { page } from '$app/state';
	import HomeStatusCard from '$lib/components/HomeStatusCard.svelte';
	import HomeProposalCard from '$lib/components/HomeProposalCard.svelte';
	import { Card } from 'flowbite-svelte';
	import { CheckCircleOutline } from 'flowbite-svelte-icons';
	import type { StatusCardInfoType } from '$lib/types/StatusCard.t';
	import type { HomeProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { statusCardInfo, proposalCardInfo } from '$lib/mock_data';

	let activeUrl = $derived(page.url.pathname);

	const statusCardInfoProps: StatusCardInfoType[] = [statusCardInfo];
	const proposalCardInfoProps: HomeProposalCardInfoType[] = [proposalCardInfo];
</script>

<div class="my-2 min-h-screen min-w-screen">
	<div class="grid h-full w-full grid-rows-3 justify-center gap-y-2">
		<!-- NOTE: UPPER SECTION -->
		<div class="flex flex-col items-center gap-y-5">
			<p class="text-3xl font-black">Community Governance Platform</p>
			<p class="text-sm font-normal text-gray-500">
				Participate in DAO decisions and shape the decentralized future
			</p>

			<div class={`w-[calc(70vw / ${statusCardInfoProps.length})] max-w-[70vw]`}>
				<HomeStatusCard {...statusCardInfoProps} />
			</div>
		</div>

		<!-- NOTE: CENTER SECTION -->
		<div class="w-full">
			<Card size="xl" shadow="xs" horizontal={false} class="min-w-[70vw] items-center gap-y-5 p-4">
				<div class="flex w-full flex-row justify-between">
					<div>
						<p class="text-xl font-bold">LEFT upper</p>
						<p class="text-lg font-normal">LEFT lower</p>
					</div>
					<div class="text-lg font-medium">RIGHT</div>
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
