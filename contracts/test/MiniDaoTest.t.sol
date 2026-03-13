// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from 'forge-std/Test.sol';
import {MiniDaoToken} from '../src/MiniDaoToken.sol';
import {Governance} from '../src/Governance.sol';
import {TimeLock} from '../src/TimeLock.sol';
import {VoteBox} from '../src/VoteBox.sol';

contract MiniDaoTest is Test {
	MiniDaoToken token;
	TimeLock timelock;
	Governance governance;
	VoteBox voteBox;
	uint256 s_minDelay = 1 hours;
	address[] s_proposers = new address[](0);
	address[] s_executors = new address[](0);

	address public USER = makeAddr('USER');
	uint256 public constant INITIAL_SUPPLY = 100 ether;

	// NOTE: setUp() will initialize and deploy the contracts
	function setUp() public {

		// 1. Deploy token, timelock and governance contracts
		token = new MiniDaoToken();
		token.mint(USER, INITIAL_SUPPLY);

		vm.startPrank(USER);
		token.delegate(USER);

		timelock = new TimeLock(s_minDelay, s_proposers, s_executors, USER);
		governance = new Governance(token, timelock);

        // 2. Grant roles to the governance contract
        // timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), USER);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governance));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // NOTE: allow anyone to execute the proposal after it's ready
        

		// 3. Revoke the timelock ownership from the deployer (USER)
		timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), USER);
		vm.stopPrank();

		voteBox = new VoteBox();
		voteBox.transferOwnership(address(timelock));
	}

    function testCannotUpdateVoteBoxWithoutGovernance() public {
        vm.expectRevert();
        voteBox.storeVote(1);
    }
}
