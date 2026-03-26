import { writeContract, waitForTransactionReceipt } from '@wagmi/core';
import { encodeFunctionData } from 'viem';
import { wagmiConfig } from '$lib/config/appKitConfig';
import MiniDaoVoteBox from '$lib/contracts_abi/MiniDaoVoteBox.json';
import MiniDaoToken from '$lib/contracts_abi/MiniDaoToken.json';
import MiniDaoGovernance from '$lib/contracts_abi/MiniDaoGovernance.json';

const VOTEBOX_ADDRESS = '0x610178dA211FEF7D417bC0e6FeD39F05609AD788';
const GOVERNANCE_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

export async function createOnChainProposal(ipfsCid: string, proposerAddress: string) {
	try {
		// 1. Prepare the execution function and pass to timelock to handle, it will run by timelock if after proposal pass by vote
		const encodedFunctionCall = encodeFunctionData({
			abi: MiniDaoVoteBox.abi,
			functionName: 'storeVote'
		});
		console.log('encodedFunctionCall: ', encodedFunctionCall);

		// 2. prepare the proposal data to pass to governance contract
		const target = [VOTEBOX_ADDRESS];
		const values = [0];
		const calldatas = [encodedFunctionCall];
		const description = `https://zippy-copper-jaguar.myfilebase.com/ipfs/${ipfsCid}`;

		// 3. create proposal by calling governance contract
		const createProposalTx = await writeContract(wagmiConfig, {
			address: GOVERNANCE_ADDRESS,
			abi: MiniDaoGovernance.abi,
			functionName: 'propose',
			args: [target, values, calldatas, description]
		});
		console.log('createProposal transaction: ', createProposalTx);

		// 4. confirm the transaction
		const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: createProposalTx });
		console.log('Transaction receipt: ', receipt);
	} catch (error) {
		console.error('❌ Error in createOnChainProposal:', error);
	}
}

