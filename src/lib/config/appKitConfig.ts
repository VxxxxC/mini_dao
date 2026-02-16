import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { mainnet, sepolia } from '@reown/appkit/networks';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import dotenv from 'dotenv';

dotenv.config();

const projectId = process.env.APPKIT_PROJECT_ID;

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
		projectId: projectId as string
	});
}

export const wagmiConfig = wagmiAdapter.wagmiConfig;
export const AppKit = appKit;
export const appKitStore = writable(appKit);
