export type AddressType = `0x${string}`;

export const Address: { [key: string]: AddressType } = {
	TIMELOCK: '0x659dB75b6a9f0115fc38082160000bf2D6adB496',
	TOKEN: '0x22252e1ffde67C761a5050e00E55BB526115D447',
	VOTEBOX: '0xab15736DFe4575c302C81133Ba83291Ab1cBc76d',
	GOVERNANCE: '0x6EF6453CB5ca1053a2361C6DFfc095A1965eDB95',
	FAUCET: '0xD796D9acCD8269b0D6714A4F17e55ab1a9e2c924'
};

export const ChainId: { [key: string]: number } = {
	ANVIL: 31337
};

