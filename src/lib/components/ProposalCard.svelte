<script lang="ts">
	import { Card } from 'flowbite-svelte';
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { Address } from '$lib/config/contractAddress';
	import { publicClient } from '$lib/config/viem/client';
	import { keccak256, toHex, encodeFunctionData } from 'viem';
	import {
		getBlock,
		writeContract,
		waitForTransactionReceipt,
		getTransactionCount
	} from '@wagmi/core';
	import ApexChart from '$lib/components/ApexChart.svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import MiniDaoVoteBox from '$lib/contracts_abi/MiniDaoVoteBox.json';
	import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';

	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import type { voteType } from '$lib/types/ProposalCard.t';
	import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';
	import { onMount } from 'svelte';

	// COL: Props
	let { proposalData, refetchData = $bindable() } = $props<{
		proposalData: ProposalCardInfoType;
		refetchData: boolean;
	}>();

	// COL: state / derived
	let pid: bigint = $state(0n);
	let connectStatus: string = $derived(walletStatus.status);
	let userAddress: string = $derived(walletStatus.address);
	let userHasVoted = $state<boolean>(false);
	let isCheckingVote = $state<boolean>(false);

	let isProcessing: boolean = $state(false);

	let proposalState = $derived<ProposalStatusEnum>(proposalData.state);

	let currentVotes = $derived<voteType>({
		againstVotes: proposalData.voteAgainst,
		forVotes: proposalData.voteFor,
		abstainVotes: proposalData.voteAbstain
	});

	const options: Intl.DateTimeFormatOptions = {
		year: 'numeric',
		month: 'long',
		day: 'numeric',
		hour: '2-digit',
		minute: '2-digit',
		second: '2-digit'
	};

	onMount(() => {
		pid = proposalData.proposalId;
	});

	$effect(() => {
		let isLoaded = false;

		if (!isLoaded) {
			if (connectStatus === 'connected') {
				checkHasVoted();
			} else {
				userHasVoted = false;
			}
			isLoaded = true;
		}

		return () => {
			isLoaded = false;
		};
	});

	function checkHasVoted() {
		isCheckingVote = true;
		publicClient
			.readContract({
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'hasVoted',
				args: [pid, userAddress]
			})
			.then((result) => {
				userHasVoted = result as boolean;
			})
			.catch((error) => {
				console.error('Failed to check vote status:', error);
			})
			.finally(() => {
				isCheckingVote = false;
			});
	}

	/*
	async function votingPeriod() {
		let result = await publicClient.readContract({
			address: Address.GOVERNANCE,
			abi: MiniDaoGovernance.abi,
			functionName: 'votingPeriod'
		});

		return Number(result);
	}
  **/

	async function queueEta() {
		let result = await publicClient.readContract({
			address: Address.GOVERNANCE,
			abi: MiniDaoGovernance.abi,
			functionName: 'proposalEta',
			args: [pid]
		});
		return Number(result) * 1000;
	}

	/************************************ NOTE: Checking the ETA for start voting ********************************************/
	let countdown = $state<number>(0);

	// Seed countdown from on-chain value and start a 1-second interval
	onMount(() => {
		(async () => {
			const block = await getBlock(wagmiConfig, { blockTag: 'latest' });
			const blockTime = Number(block.timestamp) * 1000;

			if (proposalState === ProposalStatusEnum.Pending) {
				countdown = proposalData.startToVote;
				if (proposalData.startToVote <= 0) return;

				const interval = setInterval(() => {
					const next = Math.max(0, countdown - 1);
					countdown = next;
					if (next === 0) {
						refetchData = true; // re-fetch from chain to confirm real state
						clearInterval(interval);
					}
				}, 1000 * 12); // INFO: eth 1 block per 12 seconds
				return () => clearInterval(interval);
			} else if (proposalState === ProposalStatusEnum.Active) {
				try {
					(async () => {
						countdown = proposalData.endToVote;
						if (proposalData.endToVote <= 0) return;

						const interval = setInterval(() => {
							const next = Math.max(0, countdown - 1);
							countdown = next;
							if (next === 0) {
								refetchData = true; // re-fetch from chain to confirm real state
							}
						}, 1000 * 12); // NOTE: eth 1 block per 12 seconds
						return () => clearInterval(interval);
					})();
				} catch (e) {
					console.error('Failed to fetch block timestamp or voting period:', e);
				}
			} else if (proposalState === ProposalStatusEnum.Queued) {
				const eta = await queueEta();

				const diff = (eta - blockTime) / 1000; // convert ms to seconds
				if (diff <= 0) return;
				countdown = diff;

				const interval = setInterval(() => {
					const next = Math.max(0, countdown - 1);
					countdown = next;
					if (next === 0) {
						refetchData = true; // re-fetch from chain to confirm real state
						clearInterval(interval);
					}
				}, 1000); // NOTE: eta is catching the seconds, so we don't need to counting per block
				return () => clearInterval(interval);
			}
		})();
	});

	let countdownDisplay = $derived(countdown);

	/********************************************** NOTE: Queue and Execute function call ********************************************************/
	async function handleVote(proposalId: bigint, support: number) {
		try {
			isProcessing = true;

			const latestNonce = await getTransactionCount(wagmiConfig, {
				address: userAddress as `0x${string}`,
				blockTag: 'pending'
			});

			const voteTx = await writeContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'castVote',
				args: [proposalId, support],
				nonce: latestNonce // Ensure we use the latest nonce to prevent "replacement transaction underpriced" error
			});

			const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: voteTx });

			if (receipt.status === 'success') {
				alert('🎉 Vote submitted! Your vote has been recorded on-chain.');
			}
		} catch (error) {
			console.error('Vote failed:', error);
			// Common errors: "Governor: vote already cast" or "Governor: vote not currently active"
			if (error instanceof Error && error.message.includes('already cast')) {
				alert('You have already voted on this proposal!');
			} else {
				alert(
					'Vote failed. Please ensure the voting period is active and you have delegated voting power.'
				);
			}
		} finally {
			isProcessing = false;
			refetchData = true; // re-fetch from chain to confirm real state
			checkHasVoted();
		}
	}

	let voteButtonDisable = $derived(() => {
		return proposalData.state !== ProposalStatusEnum.Active || connectStatus !== 'connected';
	});

	/********************************************** NOTE: Queue and Execute function call ********************************************************/
	const encodedFunctionCall = encodeFunctionData({
		abi: MiniDaoVoteBox.abi,
		functionName: 'storeVote'
	});

	const targets = [Address.VOTEBOX];
	const values = [0];
	const calldatas = [encodedFunctionCall];

	let descriptionHash = $derived(keccak256(toHex(proposalData.ipfsCid)));

	async function handleQueue() {
		try {
			const Tx = await writeContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'queue',
				args: [targets, values, calldatas, descriptionHash]
			});

			const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: Tx });

			if (receipt.status !== 'success') {
				throw new Error('On-chain proposal creation failed');
			} else {
				alert(`Proposal queued successfully! Tx Hash: ${receipt.transactionHash}`);
			}
		} catch (e) {
			console.error('Error in queue transaction', e);
		} finally {
			refetchData = true; // re-fetch from chain to confirm real state
		}
	}

	async function handleExecute() {
		try {
			const Tx = await writeContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'execute',
				args: [targets, values, calldatas, descriptionHash]
			});

			const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: Tx });

			if (receipt.status !== 'success') {
				throw new Error('On-chain proposal execution failed');
			} else {
				alert(`Proposal executed successfully! Tx Hash: ${receipt.transactionHash}`);
			}
		} catch (e) {
			console.error('Error in execute transaction', e);
		} finally {
			refetchData = true; // re-fetch from chain to confirm real state
		}
	}
</script>

<div class="flex flex-col items-center space-y-5">
	<Card
		size="xl"
		shadow="sm"
		horizontal={false}
		class="mb-5 h-full w-full items-start justify-between p-8 transition duration-200 ease-in-out hover:border-purple-400"
	>
		<div class="flex w-full flex-col items-center">
			<div class="flex w-full flex-row items-center justify-between">
				<div class="text-lg font-bold dark:text-white">{proposalData.title}</div>
				<div class="flex flex-row items-center space-x-2">
					{#if countdownDisplay}
						{#if proposalState === ProposalStatusEnum.Pending}
							<span
								class="flex items-center gap-1 rounded border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-xs text-amber-600 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-400"
							>
								⏳ Starting in {countdownDisplay} blocks
							</span>
						{:else if proposalState === ProposalStatusEnum.Active}
							<span
								class="flex items-center gap-1 rounded border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-xs text-amber-600 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-400"
							>
								Start Voting Now - Ends in {countdownDisplay} blocks
							</span>
						{:else if proposalState === ProposalStatusEnum.Queued}
							<span
								class="flex items-center gap-1 rounded border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-xs text-amber-600 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-400"
							>
								Execute in : {countdownDisplay} seconds
							</span>
						{/if}
					{/if}
					<ProposalStatus status={proposalState} />
				</div>
			</div>

			<div class="space-y-5 self-start">
				<div class="text-md font-light text-subtle">{proposalData.description}</div>
				<div class="flex flex-row items-center space-x-2">
					<p class="text-xs text-secondary">Proposer:</p>
					<p class="text-sm font-light text-subtle">
						{proposalData.proposer}
					</p>
				</div>
			</div>
			<ApexChart proposalInfo={proposalData} voteWeight={currentVotes} />
			<!-- FIX: need to fix below date time format-->
			<div class="flex w-full flex-row items-center justify-between">
				<div class="text-xs font-normal text-secondary">
					Vote End : {new Intl.DateTimeFormat('en-US', options).format(proposalData.expire)}
				</div>

				<div class="text-xs font-normal text-secondary">{proposalData.totalVotes} votes</div>
			</div>
		</div>
		{#if connectStatus !== 'connected'}
			<p
				class="flex w-full flex-row justify-center text-sm font-normal text-secondary dark:text-gray-400"
			>
				Please connect your wallet to vote
			</p>
		{:else}
			<div class="flex w-full flex-row items-center justify-between space-x-2">
				{#if isCheckingVote}
					<p class="animate-pulse text-gray-500 dark:text-gray-400">Checking vote record...</p>
				{:else if userHasVoted}
					{#if proposalState === ProposalStatusEnum.Active}
						<div
							class="rounded-xl border border-green-200 bg-green-50 p-4 text-center dark:border-green-800 dark:bg-green-950"
						>
							<p class="text-lg font-bold text-green-700 dark:text-green-300">
								✅ You have already voted on this proposal!
							</p>
							<p class="mt-1 text-sm text-green-600 dark:text-green-400">
								Thank you for participating in DAO governance.
							</p>
						</div>
					{:else if proposalState === ProposalStatusEnum.Succeeded}
						<button
							onclick={() => handleQueue()}
							class="min-h-12 w-full rounded-md border border-purple-300 bg-purple-50 text-purple-600 hover:bg-purple-100 dark:border-purple-700 dark:bg-purple-950 dark:text-purple-300 dark:hover:bg-purple-900"
							>To Queue</button
						>
					{:else if proposalState === ProposalStatusEnum.Queued}
						<div class="w-full space-y-2">
							<button
								onclick={() => handleExecute()}
								class="min-h-12 w-full rounded-md border border-orange-300 bg-orange-50 text-orange-600 hover:bg-orange-100 dark:border-orange-700 dark:bg-orange-950 dark:text-orange-300 dark:hover:bg-orange-900"
								>To Execute</button
							>
							<p class="text-center text-xs text-gray-400 dark:text-gray-500">
								ℹ️ Demo only — completing this step has no real-world effect.
							</p>
						</div>
					{/if}
				{:else}
					<div class="grid w-full grid-cols-7 gap-x-2">
						{#if !isProcessing}
							<button
								onclick={() => handleVote(proposalData.proposalId, 1)}
								disabled={voteButtonDisable()}
								class={[
									'col-span-3 min-h-12 rounded-md border border-green-300 bg-green-50 text-green-600 hover:bg-green-100 dark:border-green-700 dark:bg-green-950 dark:text-green-300 dark:hover:bg-green-900',
									voteButtonDisable() ? 'cursor-not-allowed opacity-30' : ''
								]}>For</button
							>
							<button
								onclick={() => handleVote(proposalData.proposalId, 2)}
								disabled={voteButtonDisable()}
								class={[
									'col-span-1 min-h-12 rounded-md border border-gray-300 bg-gray-50 text-subtle hover:bg-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:hover:bg-gray-700',
									voteButtonDisable() ? 'cursor-not-allowed opacity-30' : ''
								]}>Abstain</button
							>
							<button
								onclick={() => handleVote(proposalData.proposalId, 0)}
								disabled={voteButtonDisable()}
								class={[
									'col-span-3 min-h-12 rounded-md border border-red-300 bg-red-50 text-red-600 hover:bg-red-100 dark:border-red-700 dark:bg-red-950 dark:text-red-300 dark:hover:bg-red-900',
									voteButtonDisable() ? 'cursor-not-allowed opacity-30' : ''
								]}>Against</button
							>
						{:else}
							<button
								disabled
								class="col-span-full min-h-12 animate-pulse rounded-md bg-gray-200 disabled:cursor-wait disabled:opacity-50 dark:bg-gray-700"
								>Voting...</button
							>
						{/if}
					</div>
				{/if}
			</div>
		{/if}
	</Card>
</div>
