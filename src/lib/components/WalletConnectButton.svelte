<script lang="ts">
	import { Button } from 'flowbite-svelte';
	import { WalletOutline } from 'flowbite-svelte-icons';
	import { AppKit } from '$lib/config/appKitConfig';
	import { walletStatus } from '$lib/components/WalletStore.svelte';

	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);

	function handleClick() {
		AppKit?.open();
	}
</script>

{#if status !== 'connected'}
	<Button onclick={handleClick} color="alternative" class="p-2">
		<WalletOutline class="mr-2 h-5 w-5" />
		<p>Wallet Connect</p>
	</Button>
{:else}
	<div class="flex flex-row items-center gap-x-2">
		<Button onclick={handleClick} color="alternative" class="p-2">
			<WalletOutline class="mr-2 h-5 w-5" />
			<p>{address.slice(0, 6)}...{address.slice(-4)}</p>
		</Button>
	</div>
{/if}
