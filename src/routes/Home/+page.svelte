<script lang="ts">
	import { onMount } from 'svelte';
	import CustomButton from '$lib/components/CustomButton.svelte';
	import { page } from '$app/state';

	let activeUrl = $derived(page.url.pathname);
</script>

<div class="text-5xl text-cyan-600">This is Home Page</div>

<CustomButton />
