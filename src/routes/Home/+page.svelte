<script lang="ts">
	import { page } from '$app/state';
	import HomeStatusCard from '$lib/components/HomeStatusCard.svelte';
	import { Card } from 'flowbite-svelte';
	import { CheckCircleOutline } from 'flowbite-svelte-icons';
	import type { StatusCardInfo } from '$lib/components/HomeStatusCard.svelte';

	let activeUrl = $derived(page.url.pathname);

	const statusCardInfo: StatusCardInfo = {
		icon: CheckCircleOutline,
		iconClass: 'm-2 p-3 h-12 w-12 rounded-xl bg-cyan-50 text-cyan-300',
		cardInfo: {
			title: 'Pass Proposals',
			des: '1'
		}
	};

	const statusCardInfoProps: StatusCardInfo[] = [statusCardInfo];
</script>

<div class="my-2 min-h-screen min-w-screen">
	<div class="grid h-full w-full grid-rows-3 justify-center gap-y-2">
		<!-- NOTE: UPPER SECTION -->
		<div class="flex flex-col items-center gap-y-5">
			<p class="text-3xl font-black">Community Governance Platform</p>
			<p class="text-sm font-normal text-gray-500">
				Participate in DAO decisions and shape the decentralized future
			</p>

			<HomeStatusCard {...statusCardInfoProps} />
		</div>

		<!-- NOTE: CENTER SECTION -->
		<div class="flex min-w-[70vw] items-center justify-center">
			<Card size="xl" shadow="xs" horizontal={true} class=" p-8">
				<p>Center Container</p>
			</Card>
		</div>

		<!-- NOTE: LOWER SECTION -->
		<div class="font-black">lower column</div>
	</div>
</div>
