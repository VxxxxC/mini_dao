import { watchConnection } from '@wagmi/core';
import { wagmiConfig } from '$lib/config/appKitConfig';

export const walletStatus = $state({
	address: '',
	status: '',
	chainId: 0
});

// NOTE: wagmi EventListener for wallet connection
watchConnection(wagmiConfig, {
	onChange(account) {
		walletStatus.address = account.address ?? 'Not connected';
		walletStatus.status = account.status;
		walletStatus.chainId = account.chainId ?? 0;
	}
});
