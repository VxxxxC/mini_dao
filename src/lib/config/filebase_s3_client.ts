import { FILEBASE_ACCESS_KEY, FILEBASE_SECRET_KEY } from '$env/static/private';
import { S3Client } from '@aws-sdk/client-s3';

export const s3 = new S3Client({
	endpoint: 'https://s3.filebase.com',
	region: 'us-east-1', // NOTE: Filebase default region
	credentials: {
		accessKeyId: FILEBASE_ACCESS_KEY,
		secretAccessKey: FILEBASE_SECRET_KEY
	}
});
