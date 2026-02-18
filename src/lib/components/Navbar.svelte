<script lang="ts">
	import { Navbar, NavBrand, NavLi, NavUl } from 'flowbite-svelte';
	import { page } from '$app/state';

	let activeUrl = $derived(page.url.pathname);

	const nav = [
		{ name: 'Home', href: '/' },
		{ name: 'Proposals', href: '/proposals' },
		{ name: 'Create', href: '/create-proposal' }
	];
</script>

<div>
	<Navbar fluid={false} breakpoint="lg">
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

<style scoped>
</style>
