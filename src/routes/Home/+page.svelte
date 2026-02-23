<script lang="ts">
	import { page } from '$app/state';
	import HomeStatusCard from '$lib/components/HomeStatusCard.svelte';
	import { CheckCircleOutline } from 'flowbite-svelte-icons';

	let activeUrl = $derived(page.url.pathname);
</script>

<div class="my-2 flex flex-col items-center">
	<div class="grid h-dvh grid-rows-3 gap-y-2">
		<!-- NOTE: UPPER SECTION -->
		<div>
			<div class="flex flex-col items-center">
				<p>Community Governance Platform</p>
				<p>Participate in DAO decisions and shape the decentralized future</p>
			</div>

			<div>
				<HomeStatusCard
					icon={CheckCircleOutline}
					iconClass="m-2 p-3 h-12 w-12 rounded-xl bg-cyan-50 text-cyan-300"
				/>
			</div>
		</div>

		<!-- NOTE: CENTER SECTION -->
		<div class="font-black">center column</div>

		<!-- NOTE: LOWER SECTION -->
		<div class="font-black">lower column</div>
	</div>
</div>
