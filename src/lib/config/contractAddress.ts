export type AddressType = `0x${string}`;

export const Address : { [key: string]: AddressType } = {
    TIMELOCK: '0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35',
    TOKEN: '0xA15BB66138824a1c7167f5E85b957d04Dd34E468',
    VOTEBOX : '0x82Dc47734901ee7d4f4232f398752cB9Dd5dACcC',
    GOVERNANCE : '0xe1Aa25618fA0c7A1CFDab5d6B456af611873b629',
    FAUCET : '0xb19b36b1456E65E3A6D514D3F715f204BD59f431'
}

export const ChainId : { [key: string]: number } = {
    ANVIL : 31337
}