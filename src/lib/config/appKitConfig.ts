import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { sepolia, anvil } from '@reown/appkit/networks';
import { injected, createStorage, noopStorage, http } from '@wagmi/core';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { env as publicEnv } from '$env/dynamic/public';

let appKit: ReturnType<typeof createAppKit> | undefined = undefined;

const metadata = {
	name: 'Mini DAO',
	description: 'My Mini DAO App',
	url: 'https://mini-dao.netlify.app/',
	icons: ['https://avatars.githubusercontent.com/u/37784886']
};
// NOTE: wagmi config initialized here with reown Appkit
const wagmiAdapter = new WagmiAdapter({
	networks: [sepolia], // WARN: switch back to mainnet or sepolia for production
	transports: {
		[sepolia.id]: http('https://eth-sepolia.g.alchemy.com/v2/TDJjzSrphPPV2SRIg215Q')
	},
	projectId: publicEnv.PUBLIC_APPKIT_PROJECT_ID as string,
	connectors: [injected()],
	storage: createStorage({
		storage:
			typeof window !== 'undefined' && window.localStorage ? window.localStorage : noopStorage
	})
});

if (browser) {
	// Initialize AppKit only in browser environment
	appKit = createAppKit({
		adapters: [wagmiAdapter],
		networks: [sepolia], // WARN: switch back to mainnet or sepolia for production
		projectId: publicEnv.PUBLIC_APPKIT_PROJECT_ID as string,
		metadata: metadata,
		allWallets: 'SHOW',

		themeVariables: {
			'--apkt-z-index': 9999
		}
	});
}

export const wagmiConfig = wagmiAdapter.wagmiConfig;
export const AppKit = appKit;
export const appKitStore = writable(appKit);
