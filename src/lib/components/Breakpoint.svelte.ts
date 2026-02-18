import { browser } from '$app/environment';
import { useBreakpoints } from 'flowbite-svelte';

class Breakpoint {
	viewport = useBreakpoints();
	/* width = $state(0);
	height = $state(0);

	constructor() {
		if (browser) {
			this.width = window.innerWidth;
			this.height = window.innerHeight;

			// NOTE: EventListener for portview size
			window.addEventListener('resize', this.update, { passive: true });
		}
	}

	update = () => {
		this.width = window.innerWidth;
		this.height = window.innerHeight;
	}; */

	// NOTE: sm: 640px, md: 768px, lg: 1024px, xl: 1280px, 2xl: 1536px
	isSm = this.viewport.sm;
	isMd = this.viewport.md; // Tablet
	isLg = this.viewport.lg; // Desktop / Tablet
	isXl = this.viewport.xl;
	is2Xl = this.viewport['2xl'];

	isMobile = this.viewport.isMobile;
	isTablet = this.viewport.isTablet;
	isDesktop = this.viewport.isDesktop;
}

export const breakpoint = new Breakpoint();
