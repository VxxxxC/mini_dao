<script lang="ts">
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import { page } from '$app/state';
	import { DarkMode, Navbar, NavBrand, NavLi, NavUl, NavHamburger } from 'flowbite-svelte';
	import { getBalance, watchConnection } from '@wagmi/core';
	import { type GetBalanceReturnType } from '@wagmi/core';
	import { sepolia } from '@wagmi/core/chains';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { formatEther } from 'viem';

	let activeUrl = $derived(page.url.pathname);

	let address: string = $derived('');
	let status: string = $derived('');
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

	// NOTE: wagmi EventListener for wallet connection
	watchConnection(wagmiConfig, {
		onChange(account) {
			address = account.address ?? 'Not connected';
			status = account.status;
		}
	});

	let { children } = $props();
</script>

<div class="border-b border-b-black bg-stone-300 dark:bg-stone-700">
	<div class="mx-2 flex min-h-20 flex-row items-center justify-between">
		<Navbar fluid={true}>
			<NavUl {activeUrl}>
				<NavLi href="/">Home</NavLi>
				<NavLi href="/connectedPage">Connected</NavLi>
			</NavUl>
		</Navbar>

		<div class="flex items-center gap-x-5">
			<div class="flex flex-col items-end">
				<appkit-button></appkit-button>
				{#if status === 'connected'}
					<div class="mt-2 text-lg">
						{#await fetchBalance()}
							<p>Loading balance...</p>
						{:then}
							<p>Balance: {balance}</p>
						{:catch error}
							<p>Error fetching balance: {error.message}</p>
						{/await}
					</div>
				{/if}
			</div>
			<DarkMode />
		</div>
	</div>
</div>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
{@render children?.()}
