import { text, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { FILEBASE_BUCKET_NAME } from '$env/static/private';
import { s3 } from '$lib/config/filebase_s3_client';

export const POST: RequestHandler = async ({ request }: { request: Request }) => {
	try {
		const data = await request.json(); // NOTE: from frontend proposal data

		const bodyString = JSON.stringify(data);

		const fileName = `proposal-${Date.now()}.json`;

		const command = new PutObjectCommand({
			Bucket: FILEBASE_BUCKET_NAME,
			Key: fileName,
			Body: bodyString,
			ContentType: 'application/json'
		});

		const response = await s3.send(command);

		return json({ response: response, success: true, fileName });
	} catch (error) {
		console.error('Filebase Upload Error:', error);
		return json({ success: false, error: 'Upload failed' }, { status: 500 });
	}
};
