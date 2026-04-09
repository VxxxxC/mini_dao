<script lang="ts">
	import { onMount } from 'svelte';
	import { Card } from 'flowbite-svelte';
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { Address } from '$lib/config/contractAddress';
	import {
		readContract,
		writeContract,
		waitForTransactionReceipt,
		getTransactionCount
	} from '@wagmi/core';
	import ApexChart from '$lib/components/ApexChart.svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';

	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import type { voteType } from '$lib/types/ProposalCard.t';
	import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';

	let { proposalData, onVoteSuccess } = $props<{
		proposalData: ProposalCardInfoType;
		onVoteSuccess: () => void;
	}>();
	let connectStatus: string = $derived(walletStatus.status);
	let userAddress: string = $derived(walletStatus.address);

	$effect(() => {
		let isCancelled = false;

		const runCheck = async () => {
			if (!isCancelled) {
				await checkUserVoteStatus();
				await checkVotingWeight(proposalData.proposalId);
				await checkStartVoteSnapshot(proposalData.proposalId);
			}
		};
		if (userAddress && proposalData.proposalId) {
			runCheck();
		} else {
			userHasVoted = false;
		}

		return () => (isCancelled = true);
	});

	const options = {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};

	let currentVotes = $state<voteType>();

	// NOTE: Checking the current vote weight for each proposal
	async function checkVotingWeight(proposalId: bigint) {
		try {
			const result = await readContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'proposalVotes',
				args: [proposalId]
			});

			const { againstVotes, forVotes, abstainVotes } = result as {
				againstVotes: number;
				forVotes: number;
				abstainVotes: number;
			};

			currentVotes = { againstVotes, forVotes, abstainVotes };
		} catch (error) {
			console.error('Failed to fetch vote weight:', error);
		}
	}

	// NOTE: Checking the ETA for start voting
	let startToVote = $state<number>(0);
	let countdown = $state<number>(0);

	// Local state override — set optimistically when countdown ends
	let localState = $state<ProposalStatusEnum | undefined>(undefined);
	// Always sync localState back if parent re-fetches a new state
	let displayState = $derived(localState !== undefined ? localState : proposalData.state);

	// Seed countdown from on-chain value and start a 1-second interval
	$effect(() => {
		countdown = startToVote;
		if (startToVote <= 0) return;

		const interval = setInterval(() => {
			const next = Math.max(0, countdown - 1);
			countdown = next;
			if (next === 0) {
				clearInterval(interval);
				localState = ProposalStatusEnum.Active;
				onVoteSuccess(); // re-fetch from chain to confirm real state
			}
		}, 1000);

		return () => clearInterval(interval);
	});

	function formatCountdown(secs: number): string {
		const days = Math.floor(secs / 86400);
		const hours = Math.floor((secs % 86400) / 3600);
		const minutes = Math.floor((secs % 3600) / 60);
		const seconds = secs % 60;

		const parts: string[] = [];
		if (days > 0) parts.push(`${days}d`);
		if (hours > 0) parts.push(`${hours}h`);
		if (minutes > 0) parts.push(`${minutes}m`);
		parts.push(`${String(seconds).padStart(2, '0')}s`);
		return parts.join(' ');
	}

	let countdownDisplay = $derived(formatCountdown(countdown));

	async function checkStartVoteSnapshot(proposalId: bigint) {
		try {
			const result = await readContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'countdownStartVoting',
				args: [proposalId]
			});
			startToVote = Number(result);
		} catch (error) {
			console.error('Failed to fetch voting eta:', error);
		}
	}

	async function handleVote(proposalId: bigint, support: number) {
		try {
			console.log(`Casting vote for proposal ${proposalId} with support: ${support}`);

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

			console.log('Vote transaction submitted. Tx Hash:', voteTx);

			const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: voteTx });
			console.log('Transaction confirmed. Receipt:', receipt);

			if (receipt.status === 'success') {
				userHasVoted = true;

				alert('🎉 Vote submitted! Your vote has been recorded on-chain.');

				// NOTE: After voted success, re-fetch all the proposals status
				if (onVoteSuccess) {
					onVoteSuccess();
				}
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
		}
	}

	let userHasVoted = $state<boolean>(false);
	let isCheckingVote = $state<boolean>(false);

	async function checkUserVoteStatus() {
		if (!userAddress) return;

		try {
			isCheckingVote = true;

			const result = await readContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'hasVoted',
				args: [proposalData.proposalId, userAddress]
			});

			userHasVoted = result as boolean;
		} catch (error) {
			console.error('Failed to check vote status:', error);
		} finally {
			isCheckingVote = false;
		}
	}
</script>

<div class="flex flex-col items-center space-y-5">
	<Card
		size="xl"
		shadow="sm"
		horizontal={false}
		class="h-full w-full items-start justify-between space-y-5 p-8 transition duration-200 ease-in-out hover:border-purple-400"
	>
		<div class="flex w-full flex-col items-center">
			<div class="flex w-full flex-row items-center justify-between">
				<div class="text-lg font-bold">{proposalData.title}</div>
				<div class="flex flex-row items-center space-x-2">
					{#if countdown > 0}
						<span
							class="flex items-center gap-1 rounded border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-xs text-amber-600 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-400"
						>
							⏳ Starts in {countdownDisplay}
						</span>
					{:else}
						<span
							class="flex items-center gap-1 rounded border border-amber-200 bg-amber-50 px-2 py-1 font-mono text-xs text-amber-600 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-400"
						>
							Start Voting Now
						</span>
					{/if}
					<ProposalStatus status={displayState} />
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
					Ends: {new Intl.DateTimeFormat('en-US', options).format(proposalData.expire)}
				</div>

				<div class="text-xs font-normal text-secondary">{proposalData.totalVotes ?? 0} votes</div>
			</div>
		</div>
		{#if connectStatus !== 'connected'}
			<p class="flex w-full flex-row justify-center text-sm font-normal text-secondary">
				Please connect your wallet to vote
			</p>
		{:else}
			<div class="flex w-full flex-row items-center justify-between space-x-2">
				{#if isCheckingVote}
					<p class="animate-pulse text-gray-500">Checking vote record...</p>
				{:else if userHasVoted}
					<div class="rounded-xl border border-green-200 bg-green-50 p-4 text-center">
						<p class="text-lg font-bold text-green-700">
							✅ You have already voted on this proposal!
						</p>
						<p class="mt-1 text-sm text-green-600">
							Thank you for participating in DAO governance.
						</p>
					</div>
				{:else}
					<div class="grid w-full grid-cols-7 gap-x-2">
						<button
							onclick={() => handleVote(proposalData.proposalId, 1)}
							disabled={connectStatus !== 'connected'}
							class={[
								'col-span-3 min-h-12 rounded-md border border-green-300 bg-green-50 text-green-600 hover:bg-green-100',
								connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
							]}>For</button
						>
						<button
							onclick={() => handleVote(proposalData.proposalId, 2)}
							disabled={connectStatus !== 'connected'}
							class={[
								'col-span-1 min-h-12 rounded-md border border-gray-300 bg-gray-50 text-subtle hover:bg-gray-100',
								connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
							]}>Abstain</button
						>
						<button
							onclick={() => handleVote(proposalData.proposalId, 0)}
							disabled={connectStatus !== 'connected'}
							class={[
								'col-span-3 min-h-12 rounded-md border border-red-300 bg-red-50 text-red-600 hover:bg-red-100',
								connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
							]}>Against</button
						>
					</div>
				{/if}
			</div>
		{/if}
	</Card>
</div>
