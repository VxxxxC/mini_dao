// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from 'forge-std/Script.sol';
import {MiniDaoToken} from '../src/MiniDaoToken.sol';
import {MiniDaoVoteBox} from '../src/MiniDaoVoteBox.sol';
import {MiniDaoFaucet} from '../src/MiniDaoFaucet.sol';
import {MiniDaoGovernance} from '../src/MiniDaoGovernance.sol';
import {MiniDaoTimeLock} from '../src/MiniDaoTimeLock.sol';
import {HelperConfig} from './HelperConfig.s.sol';

contract DeployDao is Script {
	error DeployDao__FailedToTransferToFaucet();

	function run() external {
		deployDao();
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

		// WARN: Deplop treasury first!
		// IMPORTANT: Timelock -> Token -> Governance -> VoteBox


		MiniDaoTimeLock timelock = new MiniDaoTimeLock(minDelay, proposers, executors, deployer);
		console.log('timelock deployed to:', address(timelock));



		MiniDaoToken token = new MiniDaoToken(deployer, address(timelock));
		console.log('token deployed to:', address(token));
		
		MiniDaoFaucet faucet = new MiniDaoFaucet(address(token));
		console.log('faucet deployed to:', address(faucet));

		// IMPORTANT: transfer all the DAO token from deploy to the faucet for users to claim
		uint256 deployerBalance = token.balanceOf(deployer);
        bool success = token.transfer(address(faucet), deployerBalance);
		if(!success){
			revert DeployDao__FailedToTransferToFaucet();
		}
        console.log('Faucet funded with tokens:', deployerBalance);

		MiniDaoGovernance governance = new MiniDaoGovernance(token, timelock);
		console.log('governance deployed to:', address(governance));

		// Grant roles to the governance contract
		timelock.grantRole(timelock.PROPOSER_ROLE(), address(governance));
		timelock.grantRole(timelock.CANCELLER_ROLE(), address(governance));

		timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

		// Grant timelock ownership the admin role
		timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));

		// Revoke the timelock ownership from the deployer
		timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

		MiniDaoVoteBox voteBox = new MiniDaoVoteBox();
		voteBox.transferOwnership(address(timelock));
		console.log('voteBox deployed to:', address(voteBox));

		vm.stopBroadcast();
	}
}
