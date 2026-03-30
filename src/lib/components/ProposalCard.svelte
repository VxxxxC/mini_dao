<script lang="ts">
	import { onMount } from 'svelte';
	import ApexChart from '$lib/components/ApexChart.svelte';
	import { Card } from 'flowbite-svelte';
	import ProposalStatus from '$lib/components/ProposalStatus.svelte';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';
	import { Address } from '$lib/config/contractAddress';
	import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';
	import { readContract, writeContract, waitForTransactionReceipt } from '@wagmi/core';
	import { wagmiConfig } from '$lib/config/appKitConfig';

	let {proposalData, onVoteSuccess} = $props<{proposalData: ProposalCardInfoType, onVoteSuccess: () => void}>();
	let connectStatus: string = $derived(walletStatus.status);
	let userAddress: string = $derived(walletStatus.address);

	const options = {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};

	async function handleVote(proposalId: bigint, support: number) {
		try {
			console.log(`準備為提案 ${proposalId} 投下選項: ${support}`);

			// 1. 喚起 MetaMask 簽名並發送交易
			const hash = await writeContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'castVote',
				args: [proposalData.proposalId, support]
			});

			console.log('投票交易已發送，Tx Hash:', hash);

			// 2. 等待區塊鏈打包確認
			const receipt = await waitForTransactionReceipt(wagmiConfig, { hash });
			console.log('交易已確認，Receipt:', receipt);

			if (receipt.status === 'success') {
				alert('🎉 投票成功！你的聲音已記錄在區塊鏈上。');
				// 💡 呢度可以 Trigger 一個 event 去叫外層重新 fetchProposals() 刷新狀態
				onVoteSuccess();
			}
		} catch (error) {
			console.error('投票失敗:', error);
			// 常見 Error: "Governor: vote already cast" (已經投過票) 或者 "Governor: vote not currently active" (未開始/已完結)
			if (error instanceof Error && error.message.includes('already cast')) {
				alert('你已經為此提案投過票了！');
			} else {
				alert('投票失敗，請確保你在投票期內，並擁有已激活的選票 (Voting Power)。');
			}
		} finally {
			// 無論成功與否，都重新檢查用戶的投票狀態
			await checkUserVoteStatus();
		}
	}

	let userHasVoted = $state<boolean>(false);
	let isCheckingVote = $state<boolean>(false);

	async function checkUserVoteStatus() {
		if (!userAddress) return;

		try {
			isCheckingVote = true;

			// 直接 Call OpenZeppelin 自帶嘅 hasVoted
			const result = await readContract(wagmiConfig, {
				address: Address.GOVERNANCE,
				abi: MiniDaoGovernance.abi,
				functionName: 'hasVoted',
				args: [proposalData.proposalId, userAddress]
			});

			userHasVoted = result as boolean;
		} catch (error) {
			console.error('檢查投票狀態失敗:', error);
		} finally {
			isCheckingVote = false;
		}
	}

	onMount(() => {
		checkUserVoteStatus();
	});
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
				<ProposalStatus status={proposalData.state} />
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
			<ApexChart {...proposalData} />
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
					<p class="animate-pulse text-gray-500">檢查投票紀錄中...</p>
				{:else if userHasVoted}
					<div class="rounded-xl border border-green-200 bg-green-50 p-4 text-center">
						<p class="text-lg font-bold text-green-700">✅ 你已經為此提案投下神聖一票！</p>
						<p class="mt-1 text-sm text-green-600">感謝你參與 DAO 的治理決策。</p>
					</div>
				{:else}
				<div class="w-full grid grid-cols-7 gap-x-2">
					<button
						onclick={() => handleVote(proposalData.proposalId, 1)}
						disabled={connectStatus !== 'connected'}
						class={[
							'min-h-12 col-span-3 rounded-md border border-green-300 bg-green-50 text-green-600 hover:bg-green-100',
							connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
						]}>贊成</button
					>
					<button
						onclick={() => handleVote(proposalData.proposalId, 2)}
						disabled={connectStatus !== 'connected'}
						class={[
							'min-h-12 col-span-1 rounded-md border border-gray-300 bg-gray-50 text-subtle hover:bg-gray-100',
							connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
						]}>中立或棄權</button
					>
					<button
						onclick={() => handleVote(proposalData.proposalId, 0)}
						disabled={connectStatus !== 'connected'}
						class={[
							'min-h-12 col-span-3 rounded-md border border-red-300 bg-red-50 text-red-600 hover:bg-red-100',
							connectStatus !== 'connected' ? 'cursor-not-allowed opacity-30' : ''
						]}>反對</button
					>
					</div>
				{/if}
			</div>
		{/if}
	</Card>
</div>
