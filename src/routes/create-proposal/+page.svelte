<script module lang="ts">
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';
	import { Button, Card, Label, Modal } from 'flowbite-svelte';
	import { ExclamationCircleOutline } from 'flowbite-svelte-icons';
	import type { CreateProposalRequest } from '$lib/types/api/create_proposal.t';

	let connectStatus: string = $derived(walletStatus.status);
	let walletAddress: string = $derived(walletStatus.address);

	let popupModal: boolean = $state(false);

	let proposalTitle: string = $state('');
	let proposalDescription: string = $state('');

	// NOTE: send POST request to upload_proposal/+server.ts , and return API response
	async function submitProposal(event: Event) {
		event.preventDefault();

		const response = await fetch('/api/upload_proposal', {
			method: 'POST',
			body: JSON.stringify({
				proposalTitle,
				proposalDescription,
				proposerAddress: walletAddress
			} as CreateProposalRequest),
			headers: {
				'content-type': 'application/json'
			}
		});

		const result = await response.json();
		console.log({ result });
	}

	// NOTE: GET request, get proposals list
	async function getProposalList() {
		const response = await fetch('/api/get_proposals_list', {
			method: 'GET',
			headers: {
				'content-type': 'application/json'
			}
		});
		const result = await response.json();
		console.log({ result });
	}

	function submitButtonUnable(): boolean {
		if (connectStatus == 'connected') {
			if (proposalTitle.trim().length >= 5 && proposalDescription.trim().length >= 20) {
				return true;
			} else {
				return false;
			}
		}
		return false;
	}

	function cancelSubmit() {
		proposalTitle = '';
		proposalDescription = '';

		popupModal = false;
	}
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
					<form onsubmit={submitProposal} class="flex flex-col space-y-5">
						<div class="flex flex-col space-y-1">
							<Label for="title" class="text-sm font-medium text-gray-700">Proposal Title</Label>
							<input
								type="text"
								id="title"
								name="title"
								class="block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-400 focus:ring-purple-400 sm:text-sm"
								placeholder="Enter proposal title"
								bind:value={proposalTitle}
								required
							/>
							{#if proposalTitle.trim().length < 5}
								<p class="text-xs font-medium text-web3-danger">
									* Recommended minimum 5 words with proposal title
								</p>
							{/if}
						</div>
						<div class="flex flex-col space-y-1">
							<Label for="description" class="text-sm font-medium text-gray-700"
								>Proposal Description</Label
							>
							<textarea
								id="description"
								name="description"
								rows={10}
								class="block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-400 focus:ring-purple-400 sm:text-sm"
								placeholder="Enter proposal description"
								bind:value={proposalDescription}
							></textarea>
							{#if proposalDescription.trim().length < 20}
								<p class="text-xs font-medium text-web3-danger">
									* Recommended minimum 20 words with proposal details
								</p>
							{/if}
						</div>

						<div
							class="flex w-full flex-row items-start justify-start space-x-5 rounded-lg border border-purple-200 bg-purple-50 px-2 py-3 text-purple-600"
						>
							<div class="flex-col space-y-2 p-2">
								<p class="text-sm font-medium text-purple-800">Proposal Requirements</p>
								<div class="space-y-5 p-3 text-xs">
									<li>Requires staking 100 DAO tokens</li>
									<li>Voting period is 7 days</li>
									<li>Minimum 10% voter turnout required to pass</li>
									<li>Proposals cannot be modified once submitted</li>
								</div>
							</div>
						</div>
						<div class="flex flex-row items-center space-x-5">
							<button
								disabled={submitButtonUnable() !== true}
								type="button"
								onclick={() => (popupModal = true)}
								class={[
									'h-12 w-full rounded-md border border-gray-300 bg-white text-gray-600 transition duration-500 ease-in-out hover:border-red-300 hover:bg-pink-50',
									submitButtonUnable() !== true ? 'cursor-not-allowed opacity-30 ' : ''
								]}
							>
								Cancel</button
							>
							<button
								type="submit"
								disabled={submitButtonUnable() !== true}
								class={[
									'h-12 w-full rounded-md bg-linear-to-r/shorter from-indigo-400 to-purple-400 text-white transition duration-500 ease-in-out hover:from-indigo-600 hover:to-purple-600',
									submitButtonUnable() !== true ? 'cursor-not-allowed opacity-30 ' : ''
								]}>Submit Proposal</button
							>
						</div>
					</form>
				</Card>
			</div>
		</div>
	</div>
</div>

<Modal form bind:open={popupModal} size="xs" permanent>
	<div class="text-center">
		<h3 class="mb-5 text-lg font-normal text-gray-500 dark:text-gray-400">
			Are you sure you want to cancel?
		</h3>
		<div class="space-x-2">
			<Button onclick={cancelSubmit} value="yes" color="red">Yes, I'm sure</Button>
			<Button onclick={() => (popupModal = false)} value="no" color="alternative">No, cancel</Button
			>
		</div>
	</div>
</Modal>

<style scoped>
	input::placeholder,
	textarea::placeholder {
		color: lightgrey;
	}
</style>
