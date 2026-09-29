import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';
import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';
import { Address } from '$lib/config/contractAddress';
import { publicClient } from '$lib/config/viem/client';
import { formatEther } from 'viem';

const governorAbi = MiniDaoGovernance.abi;

const IPFS_GATEWAY = 'https://ipfs.filebase.io/ipfs/';

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
			expire: new Date(data.timestamp).getTime() + (30 + 60) * (1000 * 12) // INFO: (30 votingDelay + 60 votingPeriod) blocks[1 block per 12 seconds] expired
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
		const logs = await publicClient.getContractEvents({
			address: Address.GOVERNANCE,
			abi: governorAbi,
			eventName: 'ProposalCreated',
			fromBlock: 10787311n, // NOTE: checked from sepolia etherscan
			toBlock: 'latest'
		});

		const formattedProposals: ProposalCardInfoType[] = await Promise.all(
			logs.map(async (log) => {
				// viem infers args only when ABI is `as const`; cast here since JSON imports are not const
				const args = (log as unknown as { args: { proposalId: bigint; description: string } }).args;
				const proposalId = args.proposalId;
				const ipfsCid = args.description;

				// 1. Query real-time state (On-chain)
				const statePromise = publicClient.readContract({
					address: Address.GOVERNANCE,
					abi: governorAbi,
					functionName: 'state',
					args: [proposalId]
				});

				// 2. Query real-time voting start time (On-chain)
				const startVotePromise = publicClient.readContract({
					address: Address.GOVERNANCE,
					abi: governorAbi,
					functionName: 'countdownStartVoting',
					args: [proposalId]
				});

				// 3. Query real-time voting end time (On-chain)
				const endVotePromise = publicClient.readContract({
					address: Address.GOVERNANCE,
					abi: governorAbi,
					functionName: 'countdownEndVoting',
					args: [proposalId]
				});

				// 4. Query real-time voting weight (On-chain)
				const votingWeightPromise = publicClient.readContract({
					address: Address.GOVERNANCE,
					abi: governorAbi,
					functionName: 'proposalVotes',
					args: [proposalId]
				});

				// 5. Download proposal content (Off-chain IPFS)
				const ipfsPromise = fetchIpfsData(ipfsCid);

				// Wait for both requests to complete in parallel, significantly improving load speed
				const [stateResult, ipfsData, startVoteResult, endVoteResult, votingWeightResult] =
					await Promise.all([
						statePromise,
						ipfsPromise,
						startVotePromise,
						endVotePromise,
						votingWeightPromise
					]);

				// proposalVotes returns (againstVotes, forVotes, abstainVotes) as bigint tuple
				const [againstVotes, forVotes, abstainVotes] = votingWeightResult as [
					bigint,
					bigint,
					bigint
				];

				return {
					proposalId: proposalId as bigint,
					proposer: ipfsData.proposer as `0x${string}`,
					ipfsCid: ipfsCid as string,
					state: stateResult as number, // NOTE: 0 - 7 (0: Pending, 1: Active, 2: Canceled, 3: Defeated, 4: Succeeded, 5: Queued, 6: Expired, 7: Executed)
					title: ipfsData.title as string,
					description: ipfsData.description as string,
					expire: ipfsData.expire as number,
					startToVote: Number(startVoteResult),
					endToVote: Number(endVoteResult),
					// NOTE: formatEther converts bigint (wei) → string (ether); divide by 100 → 1 token = 1 voting weight
					totalVotes: Number(formatEther(againstVotes + forVotes + abstainVotes)) / 100,
					voteFor: Number(formatEther(forVotes)) / 100,
					voteAgainst: Number(formatEther(againstVotes)) / 100,
					voteAbstain: Number(formatEther(abstainVotes)) / 100
				};
			})
		);

		return formattedProposals.reverse();
	} catch (error) {
		console.error('Failed to fetch proposals:', error);
		return [];
	}
}
