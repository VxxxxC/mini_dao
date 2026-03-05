import { text, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import {
	FILEBASE_ACCESS_KEY,
	FILEBASE_SECRET_KEY,
	FILEBASE_BUCKET_NAME
} from '$env/static/private';

const s3 = new S3Client({
	endpoint: 'https://s3.filebase.com',
	region: 'us-east-1', // NOTE: Filebase default region
	credentials: {
		accessKeyId: FILEBASE_ACCESS_KEY,
		secretAccessKey: FILEBASE_SECRET_KEY
	}
});

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

		await s3.send(command);

		return json({ success: true, fileName }); // 簡化示範
	} catch (error) {
		console.error('Filebase Upload Error:', error);
		return json({ success: false, error: 'Upload failed' }, { status: 500 });
	}
};

// NOTE: This handler will respond to GET, PATCH, DELETE, etc.
export const fallback: RequestHandler = async ({ request }) => {
	return text(`I caught your ${request.method} request!`);
};
