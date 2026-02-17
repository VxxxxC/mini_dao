<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';

	let activeUrl = $derived(page.url.pathname);
</script>

<div class="text-5xl text-web3-primary">This is Home Page</div>
