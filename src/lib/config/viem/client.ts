import { createPublicClient, http } from 'viem';
import { anvil, sepolia } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: sepolia, // WARN: switch back to mainnet or sepolia for production
	transport: http('https://eth-sepolia.g.alchemy.com/v2/TDJjzSrphPPV2SRIg215Q')
});
