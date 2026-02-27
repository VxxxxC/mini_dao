<script lang="ts">
	import './layout.css';
	import Navbar from '$lib/components/Navbar.svelte';
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();
</script>

<div class="fixed top-0 z-10 w-full border-b-2 border-b-stone-300 bg-web3-bg px-5 py-1">
	<Navbar />
</div>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
<!-- PERF: Root Layout -->
<div class="relative top-32 mx-5">
	{@render children?.()}
</div>
