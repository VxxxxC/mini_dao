import { createPublicClient, http } from 'viem';
import { mainnet, sepolia } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: sepolia,
	transport: http()
});
