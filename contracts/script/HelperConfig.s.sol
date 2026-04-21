// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from 'forge-std/Script.sol';
import { CommonBase} from 'forge-std/Base.sol';


contract HelperConfig is Script {

    error HelperConfig__InvalidChainId(uint256 chainId);

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant ETH_SEPOLIA_DEPLOYER_ADDRESS = 0x0406c906ad4214E97F80F706d4203e6d1cBF5E3E; // NOTE: my metamask account address
    address constant ANVIL_DEPLOYER_ADDRESS = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720; // NOTE: Anvil account 9

	uint256 s_minDelay = 1 minutes; // TEST: for test only, normally 2 day
	address[] s_proposers = new address[](0);
	address[] s_executors = new address[](0);

	struct NetworkConfig {
		address deployer;
		uint256 minDelay;
		address[] proposers;
		address[] executors;
	}

	NetworkConfig public activeNetworkConfig;

	constructor() {
        console.log("Chain ID: ", block.chainid);
        activeNetworkConfig = getConfigByChainId(block.chainid);
	}

    function getConfig() public view returns (address, uint256, address[] memory, address[] memory) {
        return (activeNetworkConfig.deployer, activeNetworkConfig.minDelay, activeNetworkConfig.proposers, activeNetworkConfig.executors);
    }

    function getConfigByChainId(uint256 chainId) internal view returns(NetworkConfig memory){
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getSepoliaEthConfig() internal view returns (NetworkConfig memory){
        return NetworkConfig({
            deployer: ETH_SEPOLIA_DEPLOYER_ADDRESS,
            minDelay: s_minDelay,
            proposers: s_proposers,
            executors: s_executors
        });
    }

    function getAnvilEthConfig() internal view returns (NetworkConfig memory){
        return NetworkConfig({
            deployer: ANVIL_DEPLOYER_ADDRESS,
            minDelay: s_minDelay,
            proposers: s_proposers,
            executors: s_executors
        });
    }
}
