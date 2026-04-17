<script lang="ts">
	import { page } from '$app/state';
	import { walletStatus } from '$lib/components/WalletStore.svelte';
	import { readContract, writeContract, waitForTransactionReceipt } from '@wagmi/core';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import MiniDaoFaucet from '$lib/contracts_abi/MiniDaoFaucet.json';
	import MiniDaoToken from '$lib/contracts_abi/MiniDaoToken.json';
	import { Address, ChainId } from '$lib/config/contractAddress';

	let activeUrl = $derived(page.url.pathname);
	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);
	let hasClaimed: boolean = $derived(false);
	let isClaiming: boolean = $derived(false);
	let isDelegating: boolean = $derived(false);
	let isProcessing: boolean = $derived(false);
	let isLoadingStatus: boolean = $derived(false);

	$effect(() => {
		if (status === 'connected') {
			checkClaimStatus(address);
		} else {
			hasClaimed = false;
		}
	});

	async function checkClaimStatus(address: string) {
		try {
			isLoadingStatus = true;
			const result = await readContract(wagmiConfig, {
				address: Address.FAUCET,
				abi: MiniDaoFaucet.abi,
				functionName: 'hasClaimed',
				args: [address]
			});

			hasClaimed = result as boolean;
		} catch (error) {
			console.error('Loading Faucet status failed :', error);
		} finally {
			isLoadingStatus = false;
		}
	}

	async function handleClaim() {
		if (status !== 'connected') return alert('Please connect your wallet first!');

		try {
			isProcessing = true;
			isClaiming = true;

			const claimTx = await writeContract(wagmiConfig, {
				address: Address.FAUCET,
				abi: MiniDaoFaucet.abi,
				functionName: 'claim',
				chainId: ChainId.ANVIL
			});

			const claimReceipt = await waitForTransactionReceipt(wagmiConfig, { hash: claimTx });

			if (claimReceipt.status === 'success') {
				console.log(
					'Successfully claimed 100 MDAO! Please go to Delegate to activate your voting power!'
				);
			}

			isClaiming = false;

			const delegateTx = await writeContract(wagmiConfig, {
				address: Address.TOKEN,
				abi: MiniDaoToken.abi,
				functionName: 'delegate',
				args: [address],
				chainId: ChainId.ANVIL
			});

			isDelegating = true;

			const delegateReceipt = await waitForTransactionReceipt(wagmiConfig, { hash: delegateTx });
			if (delegateReceipt.status === 'success') {
				alert(
					'Successfully delegated your voting power to yourself! You can now vote on proposals!'
				);
			}
			isDelegating = false;
		} catch (error) {
			console.error('Claim failed:', error);
		} finally {
			hasClaimed = true;
			isProcessing = false;
		}
	}
</script>

<div class="rounded-2xl border border-gray-100 bg-white p-6 text-center shadow-sm">
	<h2 class="mb-2 text-xl font-bold">💰 Mini DAO Faucet</h2>
	<p class="mb-6 text-gray-500">Each person can claim 100 MDAO for governance voting</p>

	{#if status !== 'connected'}
		<button
			disabled
			class="w-full cursor-not-allowed rounded-xl bg-gray-200 px-4 py-3 font-bold text-gray-500"
		>
			Please connect your wallet first
		</button>
	{:else if isLoadingStatus}
		<button
			disabled
			class="w-full animate-pulse rounded-xl bg-blue-100 px-4 py-3 font-bold text-blue-500"
		>
			Checking eligibility...
		</button>
	{:else if hasClaimed}
		<button
			disabled
			class="flex w-full items-center justify-center gap-2 rounded-xl bg-green-100 px-4 py-3 font-bold text-green-700"
		>
			<span>✅</span> Already claimed
		</button>
	{:else}
		<button
			onclick={handleClaim}
			disabled={isProcessing}
			class="w-full rounded-xl bg-blue-600 px-4 py-3 font-bold text-white transition-colors hover:bg-blue-700 disabled:cursor-wait disabled:opacity-50"
		>
			{#if isClaiming}
				Claiming the token from the faucet...
			{:else if isDelegating}
				Delegating your voting power...
			{:else}
				Claim 100 MDAO
			{/if}
		</button>
	{/if}
</div>
