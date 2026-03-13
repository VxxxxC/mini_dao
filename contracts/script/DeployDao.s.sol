// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from 'forge-std/Script.sol';
import {MiniDaoToken} from '../src/MiniDaoToken.sol';
import {Governance} from '../src/Governance.sol';
import {TimeLock} from '../src/TimeLock.sol';
import {HelperConfig} from './HelperConfig.s.sol';

contract DeployDao is Script {
	function run() external {
		// TEST: deployDao() should run at here for normal deployment, but now comment out for testing purpose
		// deployDao();
	}

	function deployDao() public {
		HelperConfig helperConfig = new HelperConfig();

		(
			address deployer,
			uint256 minDelay,
			address[] memory proposers,
			address[] memory executors
		) = helperConfig.getConfig();

		vm.startBroadcast(deployer);

		// NOTE: Deploy token -> timelock -> governance

		MiniDaoToken token = new MiniDaoToken();
		console.log('token deployed to:', address(token));

		TimeLock timelock = new TimeLock(minDelay, proposers, executors, deployer);
		console.log('timelock deployed to:', address(timelock));

		Governance governance = new Governance(token, timelock);
		console.log('governance deployed to:', address(governance));

		vm.stopBroadcast();
	}
}
