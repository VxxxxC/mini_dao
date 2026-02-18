<script lang="ts">
	import './layout.css';
	import Navbar from '$lib/components/Navbar.svelte';
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();
</script>

<div class="border-b-2 border-b-stone-300 px-5 py-1">
	<Navbar />
</div>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
{@render children?.()}
