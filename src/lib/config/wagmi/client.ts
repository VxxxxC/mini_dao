import { createClient } from 'viem';
import { mainnet, sepolia } from '@wagmi/core/chains';
import { createConfig, createStorage, http } from '@wagmi/core';
import { sepoliaRpcUrl } from '$lib/config/dotenv';

export const wagmiConfig = createConfig({
	chains: [mainnet, sepolia],
	ssr: false,
	client({ chain }) {
		return createClient({
			chain,
			transport: http()
		});
	}
});
