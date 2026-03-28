<script lang="ts">
	import { onMount } from 'svelte';
	import { getPublicClient, readContract } from '@wagmi/core';
	import ProposalCard from '$lib/components/ProposalCard.svelte';
	import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';
	import { wagmiConfig } from '$lib/config/appKitConfig';
	import type { ProposalCardInfoType } from '$lib/types/ProposalCard.t';

	let proposals: ProposalCardInfoType[] = $state<ProposalCardInfoType[]>();
	let isLoading = $state(true);

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

	async function fetchProposals() {
		try {
			isLoading = true;
			const publicClient = getPublicClient(wagmiConfig);

			console.log('正在搜尋提案紀錄...');
			const logs = await publicClient?.getContractEvents({
				address: GOVERNOR_ADDRESS,
				abi: governorAbi,
				eventName: 'ProposalCreated',
				fromBlock: 0n,
				toBlock: 'latest'
			});

			// ==========================================
			// 🚀 效能優化：使用 Promise.all 並行處理所有提案
			// ==========================================
			const formattedProposals = await Promise.all(
				logs!.map(async (log) => {
					const args = log.args;
					const proposalId = args.proposalId;
					const ipfsCid = args.description;

					// 1. 查詢即時狀態 (On-chain)
					const statePromise = readContract(wagmiConfig, {
						address: GOVERNOR_ADDRESS,
						abi: governorAbi,
						functionName: 'state',
						args: [proposalId]
					});

					// 2. 下載提案內容 (Off-chain IPFS)
					const ipfsPromise = fetchIpfsData(ipfsCid);

					// 並行等候兩個 Request 完成，極大提升載入速度
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

			// 將最新嘅提案排喺最上面
			proposals = formattedProposals.reverse();
		} catch (error) {
			console.error('讀取提案失敗:', error);
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		fetchProposals();
	});
</script>

<div class="grid w-full space-y-5">
	<div class="flex flex-col items-start space-y-5">
		<p class="text-3xl font-bold text-gray-900">Proposals</p>
		<p class="text-sm font-normal text-gray-500">
			View all proposals and participate in voting decisions
		</p>
	</div>

	<div>
		<ProposalCard {...proposals} />
	</div>
</div>
