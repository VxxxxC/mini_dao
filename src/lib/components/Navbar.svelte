<script lang="ts">
	import { DarkMode, Navbar, NavHamburger, NavLi, NavUl, Button, Dropdown, DropdownItem } from 'flowbite-svelte';
	import { page } from '$app/state';
	import { BarsOutline } from 'flowbite-svelte-icons';
	import { getBalance } from '@wagmi/core';
	import { type GetBalanceReturnType } from '@wagmi/core';
	import { sepolia } from '@wagmi/core/chains';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { formatEther } from 'viem';
	import WalletConnectButton from '$lib/components/WalletConnectButton.svelte';
	import { walletStatus } from '$lib/components/WalletStore.svelte.ts';

	let activeUrl = $derived(page.url.pathname);
	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);
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

	const nav = [
		{ name: 'Home', href: '/' },
		{ name: 'Proposals', href: '/proposals' },
		{ name: 'Create', href: '/create-proposal' }
	];
</script>

<!-- PERF: Normal -->
<div class="hidden md:grid min-h-14 grid-cols-3 items-center justify-center gap-x-3">
	<!-- NOTE: LEFT -->
	<div class="flex flex-col items-start justify-center">
		<!-- <div class="min-h-5"><appkit-network-button></appkit-network-button></div> -->
		<DarkMode size="sm" class="rounded-xl bg-stone-300" />
	</div>

	<!-- NOTE: CENTER -->
	<div>
		<Navbar fluid={false}>
			<NavUl {activeUrl}>
				{#each nav as { name, href } (href)}
					<NavLi
						class="text-md mx-1 rounded-lg font-medium"
						activeClass="bg-web3-navbar-active-bg text-web3-navbar-active-text"
						nonActiveClass="hover:bg-gray-50 text-gray-600"
						{href}
					>
						{name}
					</NavLi>
				{/each}
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

<!-- PERF: Mobile -->
<div class="md:hidden my-2 flex justify-between">
	<DarkMode size="sm" class="rounded-xl bg-stone-300" />
<Button color="alternative">
	<BarsOutline />
	<Dropdown {activeUrl} placement="bottom" class="w-full">
		{#each nav as { name, href } (href)}
			<DropdownItem
				class="text-md mx-1 rounded-lg font-medium"
						activeClass="bg-web3-navbar-active-bg text-web3-navbar-active-text"
				{href}>
				{name}
			</DropdownItem>
		{/each}
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
	</Dropdown>
</Button>
</div>

<style scoped>
</style>
