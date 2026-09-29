import type { RequestHandler } from './$types';

import type { CreateProposalRequest } from '$lib/types/api/create_proposal.t';
import { json } from '@sveltejs/kit';
import { uploadToIPFS } from './upload_to_ipfs';

export const POST: RequestHandler = async ({ request }: { request: Request }) => {
	try {
		// NOTE: from frontend proposal data
		const data: CreateProposalRequest = await request.json();

		const upload_to_ipfs_result = await uploadToIPFS(data);

		// uploadToIPFS may return an early Response (error cases) — forward it as-is
		if (upload_to_ipfs_result instanceof Response) {
			return upload_to_ipfs_result;
		}

		if (!upload_to_ipfs_result.success || !upload_to_ipfs_result.cid) {
			return json({ success: false, error: upload_to_ipfs_result.error }, { status: 400 });
		}

		return json({ cid: upload_to_ipfs_result.cid, success: true }, { status: 200 });
	} catch (error) {
		console.error('Error in POST /api/upload_proposal:', error);
		return json({ success: false, error: 'Internal server error' }, { status: 500 });
	}
};
