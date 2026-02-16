import { createClient } from 'viem';
import { mainnet, sepolia } from '@wagmi/core/chains';
import { createConfig, http } from '@wagmi/core';
import { sepoliaRpcUrl } from '$lib/config/dotenv';

export const wagmiClient = createConfig({
	chains: [mainnet, sepolia],
	client({ chain }) {
		return createClient({
			chain,
			transport: http(sepoliaRpcUrl)
		});
	}
});
