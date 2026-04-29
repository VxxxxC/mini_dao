import { createPublicClient, http } from 'viem';
import { anvil, sepolia } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: sepolia,
	transport: http('https://ethereum-sepolia-rpc.publicnode.com') // IMPORTANT: most stable and wide limitation free RPC so far
});
