<script lang="ts">
	import { DarkMode, Navbar, NavLi, NavUl, Button, Dropdown, DropdownItem } from 'flowbite-svelte';
	import { page } from '$app/state';
	import { BarsOutline } from 'flowbite-svelte-icons';
	import { getBalance } from '@wagmi/core';
	import { type GetBalanceReturnType } from '@wagmi/core';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import { formatEther } from 'viem';
	import WalletConnectButton from '$lib/components/WalletConnectButton.svelte';
	import { walletStatus } from '$lib/components/WalletStore.svelte';

	let activeUrl = $derived(page.url.pathname);
	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);
	let balance: string = $derived('');
	let chainId: number = $derived(walletStatus.chainId);

	async function fetchBalance() {
		if (status === 'connected') {
			let result: GetBalanceReturnType = await getBalance(wagmiConfig, {
				address: `0x${address.slice(2)}`,
				chainId: chainId
			});

			balance = formatEther(result.value, 'wei').slice(0, 5) + result.symbol;
		}
	}

	const nav = [
		{ name: 'Home', href: '/' },
		{ name: 'Proposals', href: '/proposals' },
		{ name: 'Create', href: '/create-proposal' },
		{ name: 'Faucet', href: '/faucet' }
	];
</script>

<!-- PERFORMANCE: Normal -->
<div class="relative hidden min-h-14 w-full flex-row items-center justify-between gap-x-3 lg:flex">
	<!-- NOTE: LEFT -->
	<div class="flex flex-col items-start justify-center">
		<!-- <div class="min-h-5"><appkit-network-button></appkit-network-button></div> -->
		<DarkMode size="sm" class="rounded-xl bg-stone-300" />
	</div>

	<!-- NOTE: CENTER -->
	<div class="flex flex-row justify-center">
		<Navbar fluid={false}>
			<NavUl {activeUrl}>
				<div class={`flex flex-row justify-evenly gap-x-2`}>
					{#each nav as { name, href } (href)}
						<NavLi
							class="text-md mx-1 w-32 rounded-lg text-center font-medium"
							activeClass="bg-web3-navbar-active-bg text-web3-navbar-active-text"
							nonActiveClass="hover:bg-gray-50 text-gray-600"
							{href}
						>
							{name}
						</NavLi>
					{/each}
				</div>
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

<!-- PERFORMANCE: Mobile -->
<div class="relative z-0 my-2 flex justify-between lg:hidden">
	<!-- BUG: There are issue of wallet modal open, but dropdown menu is still overlay -->
	<DarkMode size="sm" class="rounded-xl bg-stone-300" />
	<Button size="sm" color="alternative">
		<BarsOutline />
		<Dropdown {activeUrl} placement="bottom" class="flex min-h-1/4 w-full flex-col justify-between">
			<div>
				{#each nav as { name, href } (href)}
					<DropdownItem
						class="text-md mx-1 flex h-12 flex-row items-center justify-center rounded-lg font-medium"
						activeClass="flex flex-row justify-center items-center h-12 bg-web3-navbar-active-bg text-web3-navbar-active-text"
						{href}
					>
						<p>{name}</p>
					</DropdownItem>
				{/each}
			</div>
			<div class="my-2 flex flex-row items-center justify-center gap-x-2">
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
