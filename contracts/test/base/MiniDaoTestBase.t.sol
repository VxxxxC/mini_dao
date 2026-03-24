// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {MiniDaoToken}      from "../../src/MiniDaoToken.sol";
import {MiniDaoFaucet}     from "../../src/MiniDaoFaucet.sol";
import {MiniDaoTimeLock}   from "../../src/MiniDaoTimeLock.sol";
import {MiniDaoGovernance} from "../../src/MiniDaoGovernance.sol";
import {MiniDaoVoteBox}    from "../../src/MiniDaoVoteBox.sol";

abstract contract MiniDaoTestBase is Test {
	// Standard actors
	address internal DEPLOYER = makeAddr("DEPLOYER");
	address internal USER_A   = makeAddr("USER_A");
	address internal USER_B   = makeAddr("USER_B");
	address internal USER_C   = makeAddr("USER_C");
	address internal ATTACKER = makeAddr("ATTACKER");

	// Contracts
	MiniDaoToken      internal token;
	MiniDaoTimeLock   internal timelock;
	MiniDaoGovernance internal governance;
	MiniDaoVoteBox    internal voteBox;
	MiniDaoFaucet     internal faucet;

	uint256 internal MIN_DELAY = 1 hours;

	/// @dev Deploy the full system: Timelock → Token → Faucet → Governance → VoteBox
	function _deployAll() internal {
		address[] memory proposers = new address[](0);
		address[] memory executors = new address[](0);

		timelock   = new MiniDaoTimeLock(MIN_DELAY, proposers, executors, DEPLOYER);
		token      = new MiniDaoToken(DEPLOYER, address(timelock));
		faucet     = new MiniDaoFaucet(address(token));

		uint256 deployerBal = token.balanceOf(DEPLOYER);
		vm.prank(DEPLOYER);
		token.transfer(address(faucet), deployerBal);

		governance = new MiniDaoGovernance(token, timelock);

		vm.startPrank(DEPLOYER);
		timelock.grantRole(timelock.PROPOSER_ROLE(),       address(governance));
		timelock.grantRole(timelock.CANCELLER_ROLE(),      address(governance));
		timelock.grantRole(timelock.EXECUTOR_ROLE(),       address(0));
		timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(),  address(timelock));
		timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER);
		vm.stopPrank();

		voteBox = new MiniDaoVoteBox();
		voteBox.transferOwnership(address(timelock));
	}

	/// @dev Claim faucet + self-delegate for an actor
	function _claimAndDelegate(address actor) internal {
		vm.startPrank(actor);
		faucet.claim();
		token.delegate(actor);
		vm.stopPrank();
	}

	/// @dev Build proposal targeting voteBox.storeVote() (correct selector)
	function _buildProposal(address target, string memory description)
		internal
		pure
		returns (
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		)
	{
		targets         = new address[](1);
		values          = new uint256[](1);
		calldatas       = new bytes[](1);
		targets[0]      = target;
		values[0]       = 0;
		calldatas[0]    = abi.encodeWithSignature("storeVote()");
		descriptionHash = keccak256(abi.encodePacked(description));
	}

	function _passVotingDelay() internal {
		// Governor clock is block-number based (Votes.clock() = block.number)
		// votingDelay = 30 seconds is interpreted as 30 blocks
		vm.roll(block.number + governance.votingDelay() + 1);
		vm.warp(block.timestamp + governance.votingDelay() + 1);
	}

	function _passVotingPeriod() internal {
		// votingPeriod = 1 days is interpreted as 1 days worth of blocks
		vm.roll(block.number + governance.votingPeriod() + 1);
		vm.warp(block.timestamp + governance.votingPeriod() + 1);
	}

	function _passTimelockDelay() internal {
		// TimelockController uses block.timestamp
		vm.warp(block.timestamp + MIN_DELAY + 1);
		vm.roll(block.number + 1);
	}

	/// @dev Full governance round-trip: propose → vote For → queue → execute
	function _proposeVoteQueueExecute(
		address proposer,
		string memory description
	) internal returns (uint256 proposalId) {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), description);

		vm.prank(proposer);
		proposalId = governance.propose(targets, values, calldatas, description);

		_passVotingDelay();

		vm.prank(proposer);
		governance.castVote(proposalId, 1); // For

		_passVotingPeriod();

		governance.queue(targets, values, calldatas, descriptionHash);
		_passTimelockDelay();
		governance.execute(targets, values, calldatas, descriptionHash);
	}
}
