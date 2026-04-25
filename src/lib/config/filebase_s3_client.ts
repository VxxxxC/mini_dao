import { env } from '$env/dynamic/private';
import { S3Client } from '@aws-sdk/client-s3';

export const s3 = new S3Client({
	endpoint: 'https://s3.filebase.com',
	region: 'us-east-1', // NOTE: Filebase default region
	credentials: {
		accessKeyId: env.FILEBASE_ACCESS_KEY,
		secretAccessKey: env.FILEBASE_SECRET_KEY
	}
});
