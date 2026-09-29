import { watchConnection } from '@wagmi/core';
import { browser } from '$app/environment';
import { wagmiConfig } from '$lib/config/appKitConfig';

export const walletStatus = $state({
	address: '',
	status: '',
	chainId: 0
});

// NOTE: wagmi EventListener for wallet connection — browser only because wagmiConfig
// is undefined on the server (WagmiAdapter is not initialized during SSR)
if (browser && wagmiConfig) {
	watchConnection(wagmiConfig, {
		onChange(account) {
			walletStatus.address = account.address ?? 'Not connected';
			walletStatus.status = account.status;
			walletStatus.chainId = account.chainId ?? 0;
		}
	});
}
