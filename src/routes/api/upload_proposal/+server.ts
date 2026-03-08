import { text, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { FILEBASE_BUCKET_NAME } from '$env/static/private';
import { s3 } from '$lib/config/filebase_s3_client';
import type { CreateProposalRequest } from '$lib/types/api/create_proposal.t';
import { publicClient } from '$lib/config/viem/client';
import { parseEther } from 'viem/utils';

const minimumGasfee = parseEther('0.001'); // Set minimum gas fee to 0.001 ETH

export const POST: RequestHandler = async ({ request }: { request: Request }) => {
	try {
		// NOTE: from frontend proposal data
		const data: CreateProposalRequest = await request.json();

		console.log({data})

		const balance = await publicClient.getBalance({
			address: `0x${data.proposerAddress.slice(2)}`
		});
		console.log('Proposer Balance:', balance);

		if (balance < minimumGasfee) {
			return json({ success: false, error: 'Insufficient balance' }, { status: 400 });
		}

		const bodyString = JSON.stringify(data);

		const fileName = `[Proposal]-${data.proposalTitle}`;

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
				console.log(cid);
				return response;
			},
			{
				step: 'build',
				name: 'addCidToOutput'
			}
		);

		const response = await s3.send(command);

		return json({ response: response, success: true, fileName });
	} catch (error) {
		console.error('Filebase Upload Error:', error);
		return json({ success: false, error: 'Upload failed' }, { status: 500 });
	}
};
