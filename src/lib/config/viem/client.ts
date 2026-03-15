import { createPublicClient, http } from 'viem';
import { mainnet, sepolia, localhost } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: localhost, // WARN: switch back to mainnet or sepolia for production
	transport: http()
});
