import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { mainnet, sepolia } from '@reown/appkit/networks';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { appKitProjectId as projectId } from '$lib/config/dotenv';

let appKit: ReturnType<typeof createAppKit> | undefined = undefined;

const wagmiAdapter = new WagmiAdapter({
	networks: [mainnet, sepolia],
	projectId: projectId as string
});

if (browser) {
	// Initialize AppKit only in browser environment
	appKit = createAppKit({
		adapters: [wagmiAdapter],
		networks: [mainnet, sepolia],
		projectId: projectId as string,

		themeVariables: {
			'--apkt-z-index': 9999
		}
	});
}

export const wagmiConfig = wagmiAdapter.wagmiConfig;
export const AppKit = appKit;
export const appKitStore = writable(appKit);
