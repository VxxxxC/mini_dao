import { text, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { ListObjectsCommand } from '@aws-sdk/client-s3';
import { FILEBASE_BUCKET_NAME } from '$env/static/private';
import { s3 } from '$lib/config/filebase_s3_client';

export const GET: RequestHandler = async () => {
	try {
		const command = new ListObjectsCommand({
			Bucket: FILEBASE_BUCKET_NAME
		});

		const response = await s3.send(command);

		return json({ response: response, success: true });
	} catch (error) {
		console.error('Filebase Get List Error:', error);
		return json({ success: false, error: 'Failed to retrieve file list' }, { status: 500 });
	}
};
