// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from 'forge-std/Script.sol';
import {MiniDaoToken} from '../src/MiniDaoToken.sol';
import {Governance} from '../src/Governance.sol';
import {TimeLock} from '../src/TimeLock.sol';

contract DeployDao is Script {
	function run() external {
        // PERFORMANCE: deployDao() should run at here for normal deployment, but now comment out for testing purpose
		// address deployer = msg.sender;
		// deployDao(deployer);
	}

	function deployDao(address deployer) internal {
        vm.startBroadcast(deployer);

		// NOTE: Deploy token -> timelock -> governance

		MiniDaoToken token = new MiniDaoToken(deployer);
		console.log('token deployed to:', address(token));

		uint256 minDelay = 2 days;
		address[] memory proposers = new address[](0);
		address[] memory executors = new address[](0);
		TimeLock timelock = new TimeLock(minDelay, proposers, executors, deployer);
		console.log('timelock deployed to:', address(timelock));

		Governance governance = new Governance(token, timelock);
		console.log('governance deployed to:', address(governance));

        vm.stopBroadcast();
	}
}
