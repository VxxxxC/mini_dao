import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { mainnet, sepolia, anvil } from '@reown/appkit/networks';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { PUBLIC_APPKIT_PROJECT_ID as projectId } from '$env/static/public';

let appKit: ReturnType<typeof createAppKit> | undefined = undefined;

// NOTE: wagmi config initialized here with reown Appkit
const wagmiAdapter = new WagmiAdapter({
	networks: [anvil], // WARN: switch back to mainnet or sepolia for production
	projectId: projectId as string
});

if (browser) {
	// Initialize AppKit only in browser environment
	appKit = createAppKit({
		adapters: [wagmiAdapter],
		networks: [anvil], // WARN: switch back to mainnet or sepolia for production
		projectId: projectId as string,

		themeVariables: {
			'--apkt-z-index': 9999
		}
	});
}

export const wagmiConfig = wagmiAdapter.wagmiConfig;
export const AppKit = appKit;
export const appKitStore = writable(appKit);
