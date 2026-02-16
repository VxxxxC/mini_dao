<script lang="ts">
	import { onMount } from 'svelte';
	import { AppKit, wagmiConfig } from '$lib/config/appKitConfig';
	import CustomButton from '$lib/components/CustomButton.svelte';
	import { page } from '$app/state';
	import { DarkMode, Navbar, NavBrand, NavLi, NavUl, NavHamburger } from 'flowbite-svelte';
	import { watchConnection } from '@wagmi/core';

	let activeUrl = $derived(page.url.pathname);

	let address: string = $derived('');
	let status: string = $derived('');

	onMount(() => {
		const unwatch = watchConnection(wagmiConfig, {
			onChange(account) {
				address = account.address ?? 'Not connected';
				status = account.status;
			}
		});

		return () => unwatch();
	});
</script>

<div class="border-b border-b-black bg-stone-300 dark:bg-stone-700">
	<div class="mx-2 flex min-h-20 flex-row items-center justify-between">
		<Navbar fluid={true}>
			<NavUl {activeUrl}>
				<NavLi href="/">Home</NavLi>
				<NavLi href="/connectedPage">Connected</NavLi>
			</NavUl>
		</Navbar>

		<div>
			<DarkMode />
		</div>
	</div>
</div>
<div class="text-5xl text-cyan-600">This is Home Page</div>
<button class="rounded-xl border-2 border-white bg-gray-700 p-2 text-white">
	<appkit-button></appkit-button>
</button>

<div class="mt-4 text-lg">Connected Address: {address}</div>
<div class="mt-2 text-lg">Connection Status: {status}</div>

<CustomButton />
