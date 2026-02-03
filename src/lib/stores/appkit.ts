import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { arbitrum, mainnet, sepolia } from '@reown/appkit/networks';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';

let appKit: ReturnType<typeof createAppKit> | undefined = undefined;

const wagmiAdapter = new WagmiAdapter({
	networks: [sepolia],
	projectId: 'd5a41a5aa6d41052405a96df5f04fd6c'
});

if (browser) {
	// Initialize AppKit only in browser environment
	appKit = createAppKit({
		adapters: [wagmiAdapter],
		networks: [sepolia],
		projectId: 'd5a41a5aa6d41052405a96df5f04fd6c'
	});
}

export const AppKit = appKit;
export const appKitStore = writable(appKit);
