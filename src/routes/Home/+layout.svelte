<script lang="ts">
	import { page } from '$app/state';
	import { DarkMode, Navbar, NavBrand, NavLi, NavUl, NavHamburger } from 'flowbite-svelte';
	let activeUrl = $derived(page.url.pathname);

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

		<div>
			<DarkMode />
		</div>
	</div>
</div>

{@render children()}
