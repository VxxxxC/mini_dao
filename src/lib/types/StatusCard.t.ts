import type { Component } from 'svelte';

export interface StatusCardInfoType {
	icon: Component;
	iconClass: string;
	cardInfo: {
		title: string;
		des: string;
	};
}
