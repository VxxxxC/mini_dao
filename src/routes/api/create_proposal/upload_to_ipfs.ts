import { json } from '@sveltejs/kit';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { FILEBASE_BUCKET_NAME } from '$env/static/private';
import { s3 } from '$lib/config/filebase_s3_client';
import type { CreateProposalRequest } from '$lib/types/api/create_proposal.t';
import { publicClient } from '$lib/config/viem/client';
import { parseEther, verifyMessage } from 'viem/utils';

type ProposalToIPFS = Omit<CreateProposalRequest, 'messageToSign'>;

const MINIMUM_GAS_FEE = parseEther('0.001'); // Set minimum gas fee to 0.001 ETH
const FIVE_MINUTES_TIMEOUT = 5 * 60 * 1000; // 5 minutes in milliseconds

export async function uploadToIPFS(data: CreateProposalRequest) {
	try {
		// IMPORTANT: Check if the signature is expired (older than 5 minutes)
		if (Date.now() - Date.parse(data.timestamp) > FIVE_MINUTES_TIMEOUT) {
			return json(
				{ success: false, error: '❌ Signature expired, Please sign again!' },
				{ status: 400 }
			);
		}
		console.log('✅ Signature within validity period');

		// IMPORTANT: Verify the signature to ensure the request is authentic
		const expectedMessage = `Create proposal [${data.proposalTitle}] at ${data.timestamp}`;
		if (data.messageToSign !== expectedMessage) {
			return json({ success: false, error: '❌ Signed message mismatch!' }, { status: 400 });
		}
		console.log('✅ Message to sign matches expected format');

		const isValidSignature = verifyMessage({
			address: `0x${data.proposerAddress.slice(2)}`,
			message: data.messageToSign,
			signature: `0x${data.signature.slice(2)}`
		});
		if (!isValidSignature) {
			return json({ success: false, error: '❌ Invalid signature!' }, { status: 400 });
		}
		console.log('✅ Signature is valid');

		// Check if the proposer has enough balance to cover gas fees
		const balance = await publicClient.getBalance({
			address: `0x${data.proposerAddress.slice(2)}`
		});
		if (balance < MINIMUM_GAS_FEE) {
			return json({ success: false, error: '❌ Insufficient balance' }, { status: 400 });
		}
		console.log('✅ Proposer has sufficient balance for gas fees');

		const proposalDataForIPFS: ProposalToIPFS = {
			proposalTitle: data.proposalTitle,
			proposalDescription: data.proposalDescription,
			proposerAddress: data.proposerAddress,
			signature: data.signature,
			timestamp: data.timestamp
		};

		const bodyString = JSON.stringify(proposalDataForIPFS);

		const fileName = `[Proposal]-${data.proposalTitle}.json`;

		const ipfsCid: string[] = new Array(1);

		const command = new PutObjectCommand({
			Bucket: FILEBASE_BUCKET_NAME,
			Key: fileName,
			Body: bodyString,
			ContentType: 'application/json'
		});

		// IMPORTANT: Below code is extract IPFS CID from response header after upload data to filebase
		command.middlewareStack.add(
			(next) => async (args) => {
				// Check if request is incoming as middleware works both ways
				const response = await next(args);
				if (!response.response.statusCode) return response;

				// Get cid from headers
				const cid = response.response.headers['x-amz-meta-cid'];
				if (cid) {
					ipfsCid[0] = cid;
				}
				return response;
			},
			{
				step: 'build',
				name: 'addCidToOutput'
			}
		);

		console.log('\n✅ Verification OK ! uploading file to Filebase S3...');

		await s3.send(command);

		console.log('\n✅ Upload completed!!');

		return ipfsCid[0] ? { success: true, cid: ipfsCid[0] } : { success: false, error: '❌ Failed to retrieve IPFS CID from response' };
	} catch (error) {
		console.error('❌ Filebase Upload Error:', error);
		return { success: false, error: '❌ Filebase Upload Error' };
	}
}

