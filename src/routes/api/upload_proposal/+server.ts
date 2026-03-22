
import type { RequestHandler } from './$types';

import type { CreateProposalRequest } from '$lib/types/api/create_proposal.t';
import { json } from '@sveltejs/kit';
import { uploadToIPFS } from './upload_to_ipfs';
import { createOnChainProposal } from './proposal_to_chain';

export const POST: RequestHandler = async ({ request }: { request: Request }) => {

	try {
		// NOTE: from frontend proposal data
		const data: CreateProposalRequest = await request.json();

		const upload_to_ipfs_result = await uploadToIPFS(data);
		const { response , ipfsCid } = upload_to_ipfs_result;

		const create_on_chain_proposal_result = await createOnChainProposal(ipfsCid, data.proposerAddress);

		return json({ success: true }, { status: 200 });
	} catch (error) {
		console.error('Error in POST /api/upload_proposal:', error);
		return json({ success: false, error: 'Internal server error' }, { status: 500 });
	}
};
