import type { Component } from 'svelte';

export interface StatusCardInfo {
	icon: Component;
	iconClass: string;
	cardInfo: {
		title: string;
		des: string;
	};
}
