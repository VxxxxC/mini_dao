export type CreateProposalRequest = {
	proposalTitle: string;
	proposalDescription: string;
	proposerAddress: string;
	messageToSign: string;
	signature: string;
	timestamp: string;
};
