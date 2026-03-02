<script lang="ts">
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';
	import { Card } from 'flowbite-svelte';
	import { ExclamationCircleOutline } from 'flowbite-svelte-icons';

	let connectStatus: string = $derived(walletStatus.status);
</script>

<div class="grid w-full grid-cols-5">
	<div
		class="col-start-1 col-end-6 flex flex-col items-start space-y-5 md:col-start-2 md:col-end-5"
	>
		<div class="space-y-5">
			<p class="text-3xl font-bold text-gray-900">Create New Proposal</p>
			<p class="text-sm font-normal text-gray-500">Submit your ideas and let the community vote</p>
		</div>
		<div class="w-full space-y-5">
			{#if connectStatus !== 'connected'}
				<div
					class="flex w-full flex-row items-start justify-start space-x-5 rounded-lg border border-yellow-200 bg-yellow-50 px-2 py-3 text-yellow-600"
				>
					<ExclamationCircleOutline size="lg" />
					<div class="flex-col space-y-2">
						<p class="text-sm font-medium text-yellow-800">Wallet Connection Required</p>
						<p class="text-xs">Please connect your wallet to create a proposal.</p>
					</div>
				</div>
			{/if}

			<div>
				<Card size="xl" shadow="md" horizontal={false} class="h-full w-full space-y-5 p-8">
					<form class="flex flex-col space-y-5">
						<div class="flex flex-col space-y-1">
							<label for="title" class="text-sm font-medium text-gray-700">Proposal Title</label>
							<input
								type="text"
								id="title"
								name="title"
								class="block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-400 focus:ring-purple-400 sm:text-sm"
								placeholder="Enter proposal title"
							/>
						</div>
						<div class="flex flex-col space-y-1">
							<label for="description" class="text-sm font-medium text-gray-700"
								>Proposal Description</label
							>
							<textarea
								id="description"
								name="description"
								rows="4"
								class="block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-400 focus:ring-purple-400 sm:text-sm"
								placeholder="Enter proposal description"
							></textarea>
						</div>
						<button
							type="submit"
							class={[
								'h-12 w-full rounded-md border border-blue-300 bg-blue-50 text-blue-600 hover:bg-blue-100',
								connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
							]}>Submit Proposal</button
						>
					</form>

					<div
						class="flex w-full flex-row items-start justify-start space-x-5 rounded-lg border border-purple-200 bg-purple-50 px-2 py-3 text-purple-600"
					>
						<div class="flex-col space-y-2">
							<p class="text-sm font-medium text-purple-800">Proposal Requirements</p>
							<p class="text-xs">Please connect your wallet to create a proposal.</p>
						</div>
					</div>
				</Card>
			</div>
		</div>
	</div>
</div>

<style scoped>
	input::placeholder,
	textarea::placeholder {
		color: lightgrey;
	}
</style>
