export type AddressType = `0x${string}`;

export const Address : { [key: string]: AddressType } = {
    VOTEBOX : '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
    GOVERNANCE : '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    FAUCET : '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'
}

export const ChainId : { [key: string]: number } = {
    ANVIL : 31337
}