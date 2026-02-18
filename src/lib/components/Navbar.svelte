<script lang="ts">
	import { Navbar, NavBrand, NavLi, NavUl } from 'flowbite-svelte';
	import { page } from '$app/state';

	let activeUrl = $derived(page.url.pathname);
</script>

<div>
	<Navbar fluid={false} breakpoint="lg">
		<NavUl {activeUrl}>
			<NavLi href="/">Home</NavLi>
			<NavLi href="/connectedPage">Connected</NavLi>
		</NavUl>
	</Navbar>
</div>
