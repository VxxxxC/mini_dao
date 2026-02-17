<script lang="ts">
	import './layout.css';
	import WalletConnectButton from '$lib/components/WalletConnectButton.svelte';
	import favicon from '$lib/assets/favicon.svg';
	import { page } from '$app/state';
	import { DarkMode, Navbar, NavBrand, NavLi, NavUl, NavHamburger } from 'flowbite-svelte';
	import { getBalance } from '@wagmi/core';
	import { type GetBalanceReturnType } from '@wagmi/core';
	import { sepolia } from '@wagmi/core/chains';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { formatEther } from 'viem';
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';

	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);

	let activeUrl = $derived(page.url.pathname);

	let balance: string = $derived('');

	async function fetchBalance() {
		if (status === 'connected') {
			let result: GetBalanceReturnType = await getBalance(wagmiConfig, {
				address: `0x${address.slice(2)}`,
				chainId: sepolia.id
			});

			balance = formatEther(result.value, 'wei').slice(0, 5) + result.symbol;
		}
	}

	let { children } = $props();
</script>

<div class="border-b-2 border-b-stone-300 bg-stone-100 px-5 py-1 dark:bg-stone-700">
	<div class="flex grid min-h-14 grid-cols-3 items-center justify-center gap-x-3">
		<!-- NOTE: LEFT -->
		<div class="flex flex-col items-start justify-center">
			<!-- <div class="min-h-5"><appkit-network-button></appkit-network-button></div> -->
			<DarkMode size="sm" class="rounded-xl bg-stone-300" />
		</div>

		<!-- NOTE: CENTER -->
		<div>
			<Navbar fluid={false} breakpoint="lg">
				<NavUl {activeUrl}>
					<NavLi href="/">Home</NavLi>
					<NavLi href="/connectedPage">Connected</NavLi>
				</NavUl>
			</Navbar>
		</div>

		<!-- NOTE: RIGHT -->
		<div class="flex flex-row items-center justify-end-safe gap-x-2">
			{#if status === 'connected'}
				<div>
					{#await fetchBalance()}
						<p>Loading balance...</p>
					{:then}
						<div
							class="flex h-8 flex-row items-center justify-center gap-x-5 rounded-xl bg-stone-300 p-2 font-mono text-sm"
						>
							<p>Balance:</p>
							<p>{balance}</p>
						</div>
					{:catch error}
						<p>Error fetching balance: {error.message}</p>
					{/await}
				</div>
			{/if}

			<div>
				<WalletConnectButton />
			</div>
		</div>
	</div>
</div>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
{@render children?.()}
