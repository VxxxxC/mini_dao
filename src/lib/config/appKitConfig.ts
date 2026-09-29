import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { sepolia } from '@reown/appkit/networks';
import { injected, createStorage, noopStorage, http } from '@wagmi/core';
import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import { env as publicEnv } from '$env/dynamic/public';

let appKit: ReturnType<typeof createAppKit> | undefined = undefined;
let wagmiAdapter: WagmiAdapter | undefined = undefined;

const metadata = {
	name: 'Mini DAO',
	description: 'My Mini DAO App',
	url: 'https://mini-dao.netlify.app/',
	icons: ['https://avatars.githubusercontent.com/u/37784886']
};

if (browser) {
	// NOTE: wagmi config initialized here with reown Appkit — browser only to avoid
	// loading WalletConnect's large dependency tree in the Netlify SSR function
	wagmiAdapter = new WagmiAdapter({
		networks: [sepolia],
		transports: {
			[sepolia.id]: http('https://ethereum-sepolia-rpc.publicnode.com') // IMPORTANT: most stable and wide limitation free RPC so far
		},
		projectId: publicEnv.PUBLIC_APPKIT_PROJECT_ID as string,
		connectors: [injected()],
		storage: createStorage({
			storage: window.localStorage ?? noopStorage
		})
	});

	appKit = createAppKit({
		adapters: [wagmiAdapter],
		networks: [sepolia],
		projectId: publicEnv.PUBLIC_APPKIT_PROJECT_ID as string,
		metadata: metadata,
		allWallets: 'SHOW',

		themeVariables: {
			'--apkt-z-index': 9999
		}
	});
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const wagmiConfig = wagmiAdapter?.wagmiConfig as any;
export const AppKit = appKit;
export const appKitStore = writable(appKit);
