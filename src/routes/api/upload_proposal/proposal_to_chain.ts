import { writeContract, waitForTransactionReceipt } from "@wagmi/core";
import { encodeFunctionData } from "viem";
import { wagmiConfig } from "$lib/config/appKitConfig";
import MiniDaoVoteBox from "$lib/contracts_abi/MiniDaoVoteBox.json";
import MiniDaoToken from "$lib/contracts_abi/MiniDaoToken.json";
import MiniDaoGovernance from "$lib/contracts_abi/MiniDaoGovernance.json"

let VOTEBOX_ADDRESS = "0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1";
let GOVERNANCE_ADDRESS = "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1";

async function createOnChainProposal(ipfsCid: string, proposerAddress: string) {
    try {
        // 1. Prepare the execution function and pass to timelock to handle, it will run by timelock if after proposal pass by vote 
        const encodedFunctionCall = encodeFunctionData({
            abi: MiniDaoVoteBox.abi,
            functionName: "storeVote",
        })
        console.log("encodedFunctionCall: ", encodedFunctionCall);

        // 2. prepare the proposal data to pass to governance contract
        const target = [VOTEBOX_ADDRESS];
        const values = [0];
        const calldatas = [encodedFunctionCall];
        const description = `https://zippy-copper-jaguar.myfilebase.com/ipfs/${ipfsCid}`;

        // 3. create proposal by calling governance contract
        const createProposalTx = await writeContract(wagmiConfig, {
            address: GOVERNANCE_ADDRESS,
            abi: MiniDaoGovernance.abi,
            functionName: "propose",
            args: [target, values, calldatas, description],
        });
        console.log("createProposal transaction: ", createProposalTx);

        // 4. confirm the transaction
      const receipt = await waitForTransactionReceipt(wagmiConfig, { hash: createProposalTx });
      console.log("Transaction receipt: ", receipt);
      
    } catch (error) {
        console.error('❌ Error in createOnChainProposal:', error);
    }

}