
import { getPublicClient, readContract } from '@wagmi/core';
import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';
import { wagmiConfig } from '$lib/config/appKitConfig';
import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';


const GOVERNOR_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';
const governorAbi = MiniDaoGovernance.abi;

const IPFS_GATEWAY =
	'https://ipfs.filebase.io/ipfs/';

async function fetchIpfsData(cid: string) {
	try {
		// Append the CID to the Gateway URL
		const response = await fetch(`${IPFS_GATEWAY}${cid}`);

		if (!response.ok) {
			throw new Error(`HTTP error! status: ${response.status}`);
		}

		const data = await response.json();
		return {
			title: data.proposalTitle || 'Untitled',
			description: data.proposalDescription || 'No content',
			proposer: data.proposerAddress || 'Unknown',
			expire: new Date(data.timestamp).getTime() + 7 * 24 * 60 * 60 * 1000, // INFO: 7 days expired
		};
	} catch (error) {
		console.error(`Load IPFS data failed (CID: ${cid}):`, error);
		return {
			title: '⚠️ Failed to load proposal title',
			description: 'IPFS node did not respond, please try again later.'
		};
	}
}

export async function fetchProposals() {
	try {
		const publicClient = getPublicClient(wagmiConfig);

		console.log('Finding Proposals Data...');
		const logs = await publicClient?.getContractEvents({
			address: GOVERNOR_ADDRESS,
			abi: governorAbi,
			eventName: 'ProposalCreated',
			fromBlock: 0n,
			toBlock: 'latest'
		});

		const formattedProposals = await Promise.all(
			logs!.map(async (log) => {
				const args = log.args;
				const proposalId = args.proposalId;
				const ipfsCid = args.description;

				// 1. Query real-time state (On-chain)
				const statePromise = readContract(wagmiConfig, {
					address: GOVERNOR_ADDRESS,
					abi: governorAbi,
					functionName: 'state',
					args: [proposalId]
				});

					// 2. Download proposal content (Off-chain IPFS)
				const ipfsPromise = fetchIpfsData(ipfsCid);

				// Wait for both requests to complete in parallel, significantly improving load speed
				const [stateResult, ipfsData] = await Promise.all([statePromise, ipfsPromise]);

				return {
					proposalId: proposalId as `0x${string}`,
					proposer: ipfsData.proposer as `0x${string}`,
					ipfsCid: ipfsCid as string,
					state: stateResult as number,
					title: ipfsData.title as string,
					description: ipfsData.description as string,
					expire: ipfsData.expire as number,
				};
			})
		);

		return formattedProposals.reverse();
	} catch (error) {
		console.error('Failed to fetch proposals:', error);
		return [];
	}
}