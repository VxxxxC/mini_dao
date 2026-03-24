// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MiniDaoVoteBox}  from "../../src/MiniDaoVoteBox.sol";

contract MiniDaoVoteBoxTest is MiniDaoTestBase {
	address internal voteBoxOwner;

	function setUp() public {
		voteBoxOwner = makeAddr("VOTE_BOX_OWNER");
		voteBox      = new MiniDaoVoteBox();
		voteBox.transferOwnership(voteBoxOwner);
	}

	function testInitialVoteCountIsZero() public view {
		assertEq(voteBox.getVote(), 0, "initial vote count should be 0");
	}

	function testInitialOwnerIsDeployer() public view {
		assertEq(voteBox.owner(), voteBoxOwner, "owner should be voteBoxOwner");
	}

	function testStoreVoteRevertsForNonOwner() public {
		vm.prank(ATTACKER);
		vm.expectRevert();
		voteBox.storeVote();
	}

	function testStoreVoteSucceedsForOwner() public {
		vm.prank(voteBoxOwner);
		voteBox.storeVote(); // should not revert
	}

	function testStoreVoteIncrementsCount() public {
		vm.prank(voteBoxOwner);
		voteBox.storeVote();
		assertEq(voteBox.getVote(), 1, "count should be 1");
	}

	function testStoreVoteIncrementsMultipleTimes() public {
		vm.startPrank(voteBoxOwner);
		for (uint256 i; i < 5; i++) {
			voteBox.storeVote();
		}
		vm.stopPrank();
		assertEq(voteBox.getVote(), 5, "count should be 5");
	}

	function testStoreVoteEmitsVoteCastedEvent() public {
		vm.expectEmit(false, false, false, true, address(voteBox));
		emit MiniDaoVoteBox.VoteCasted(1);

		vm.prank(voteBoxOwner);
		voteBox.storeVote();
	}

	function testStoreVoteEmitsCorrectCountInEvent() public {
		vm.startPrank(voteBoxOwner);
		voteBox.storeVote();
		voteBox.storeVote();

		vm.expectEmit(false, false, false, true, address(voteBox));
		emit MiniDaoVoteBox.VoteCasted(3);
		voteBox.storeVote();
		vm.stopPrank();
	}

	function testTransferOwnershipToTimelock() public {
		address newOwner = makeAddr("NEW_TIMELOCK");
		vm.prank(voteBoxOwner);
		voteBox.transferOwnership(newOwner);
		assertEq(voteBox.owner(), newOwner, "owner should be new timelock");
	}

	function testOldOwnerCannotCallStoreVoteAfterTransfer() public {
		address newOwner = makeAddr("NEW_TIMELOCK2");
		vm.prank(voteBoxOwner);
		voteBox.transferOwnership(newOwner);

		vm.prank(voteBoxOwner);
		vm.expectRevert();
		voteBox.storeVote();
	}
}
