import { createPublicClient, http } from 'viem';
import { anvil, sepolia } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: sepolia, // WARN: switch back to mainnet or sepolia for production
	transport: http()
});
