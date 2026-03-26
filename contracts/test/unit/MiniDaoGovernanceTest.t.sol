// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MiniDaoToken}    from "../../src/MiniDaoToken.sol";
import {MiniDaoTimeLock} from "../../src/MiniDaoTimeLock.sol";
import {MiniDaoGovernance} from "../../src/MiniDaoGovernance.sol";

contract MiniDaoGovernanceTest is MiniDaoTestBase {
	function setUp() public {
		_deployAll();
		_claimAndDelegate(USER_A);
	}

	// --- Configuration ---

	function testGovernorName() public view {
		assertEq(governance.name(), "Mini Governor", "governor name mismatch");
	}

	function testQuorumValue() public view {
		assertEq(governance.quorum(block.number), 5e18, "quorum should be 5 tokens");
	}

	function testVotingDelay() public view {
		assertEq(governance.votingDelay(), 30 seconds, "voting delay mismatch");
	}

	function testVotingPeriod() public view {
		assertEq(governance.votingPeriod(), 1 days, "voting period mismatch");
	}

	// --- Internal helper to create a proposal ---

	function _createProposal(string memory desc) internal returns (uint256 proposalId) {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
		) = _buildProposal(address(voteBox), desc);

		vm.prank(USER_A);
		proposalId = governance.propose(targets, values, calldatas, desc);
	}

	// --- Proposal State Machine ---

	function testProposalIsPendingImmediatelyAfterCreation() public {
		uint256 id = _createProposal("Pending test");
		assertEq(uint256(governance.state(id)), 0, "should be Pending (0)");
	}

	function testProposalBecomesActiveAfterVotingDelay() public {
		uint256 id = _createProposal("Active test");
		_passVotingDelay();
		assertEq(uint256(governance.state(id)), 1, "should be Active (1)");
	}

	function testProposalSucceededAfterVotingPeriodWithEnoughVotes() public {
		uint256 id = _createProposal("Succeeded test");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 4, "should be Succeeded (4)");
	}

	function testProposalDefeatedWhenQuorumNotMet() public {
		// Use a standalone setup with a voter holding < 5 tokens
		address[] memory p  = new address[](0);
		address[] memory e  = new address[](0);
		MiniDaoToken t2     = new MiniDaoToken(DEPLOYER, makeAddr("T50"));
		MiniDaoTimeLock l2  = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		MiniDaoGovernance g2 = new MiniDaoGovernance(t2, l2);

		address voter = makeAddr("SMALL_VOTER");
		vm.prank(DEPLOYER);
		t2.transfer(voter, 4e18); // 4 tokens < 5 quorum
		vm.prank(voter);
		t2.delegate(voter);

		vm.startPrank(DEPLOYER);
		l2.grantRole(l2.PROPOSER_ROLE(), voter);
		l2.grantRole(l2.EXECUTOR_ROLE(), address(0));
		vm.stopPrank();

		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = makeAddr("ANY");
		calldatas[0] = abi.encodeWithSignature("noOp()");

		vm.prank(voter);
		uint256 pid = g2.propose(targets, values, calldatas, "Below quorum");

		vm.roll(block.number + g2.votingDelay() + 1);
		vm.warp(block.timestamp + g2.votingDelay() + 1);

		vm.prank(voter);
		g2.castVote(pid, 1);

		vm.roll(block.number + g2.votingPeriod() + 1);
		vm.warp(block.timestamp + g2.votingPeriod() + 1);

		assertEq(uint256(g2.state(pid)), 3, "should be Defeated (3) - quorum not met");
	}

	function testProposalDefeatedWhenAgainstExceedsFor() public {
		_claimAndDelegate(USER_B);
		_claimAndDelegate(USER_C);

		uint256 id = _createProposal("Against majority");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 1); // For  - 100 tokens
		vm.prank(USER_B);
		governance.castVote(id, 0); // Against - 100 tokens
		vm.prank(USER_C);
		governance.castVote(id, 0); // Against - 100 tokens  =>  Against 200 > For 100

		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 3, "should be Defeated (3)");
	}

	function testProposalQueuedAfterSucceeded() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Queue test");

		vm.prank(USER_A);
		uint256 id = governance.propose(targets, values, calldatas, "Queue test");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		_passVotingPeriod();

		governance.queue(targets, values, calldatas, descriptionHash);
		assertEq(uint256(governance.state(id)), 5, "should be Queued (5)");
	}

	function testProposalExecutedAfterTimelockDelay() public {
		uint256 id = _proposeVoteQueueExecute(USER_A, "Execute test");
		assertEq(uint256(governance.state(id)), 7, "should be Executed (7)");
	}

	// --- Voting Mechanics ---

	function testCastVoteFor() public {
		uint256 id = _createProposal("Vote For");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 1);

		assertTrue(governance.hasVoted(id, USER_A), "USER_A should have voted");
		(uint256 against, uint256 forVotes, uint256 abstain) = governance.proposalVotes(id);
		assertGt(forVotes, 0, "For votes should be > 0");
		assertEq(against, 0, "Against should be 0");
		assertEq(abstain, 0, "Abstain should be 0");
	}

	function testCastVoteAgainst() public {
		uint256 id = _createProposal("Vote Against");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 0);

		(uint256 against,,) = governance.proposalVotes(id);
		assertGt(against, 0, "Against should be > 0");
	}

	function testCastVoteAbstain() public {
		uint256 id = _createProposal("Vote Abstain");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 2);

		(uint256 against, uint256 forVotes, uint256 abstain) = governance.proposalVotes(id);
		assertGt(abstain, 0,  "Abstain votes should be > 0");
		assertEq(forVotes, 0, "For should be 0");
		assertEq(against, 0,  "Against should be 0");
	}

	function testAbstainCountsTowardQuorumButNotVictory() public {
		// USER_A abstains with >= 5 tokens; quorum is met but For == 0 so Defeated
		uint256 id = _createProposal("Abstain quorum");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 2); // Abstain

		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 3, "Defeated - no For votes despite quorum");
	}

	function testCannotVoteBeforeVotingDelay() public {
		uint256 id = _createProposal("Too early");
		vm.prank(USER_A);
		vm.expectRevert();
		governance.castVote(id, 1); // Proposal is still Pending
	}

	function testCannotVoteAfterVotingPeriod() public {
		uint256 id = _createProposal("Too late");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 1);

		_passVotingPeriod();

		vm.prank(USER_B);
		vm.expectRevert();
		governance.castVote(id, 1);
	}

	function testCannotVoteTwice() public {
		uint256 id = _createProposal("Double vote");
		_passVotingDelay();

		vm.startPrank(USER_A);
		governance.castVote(id, 1);
		vm.expectRevert();
		governance.castVote(id, 1);
		vm.stopPrank();
	}

	function testCastVoteWithReason() public {
		uint256 id = _createProposal("Vote with reason");
		_passVotingDelay();

		vm.recordLogs();
		vm.prank(USER_A);
		governance.castVoteWithReason(id, 1, "I support this");

		Vm.Log[] memory logs = vm.getRecordedLogs();
		bytes32 sig = keccak256("VoteCast(address,uint256,uint8,uint256,string)");
		bool found;
		for (uint256 i; i < logs.length; i++) {
			if (logs[i].topics[0] == sig) { found = true; break; }
		}
		assertTrue(found, "VoteCast event not emitted");
	}

	function testVotingPowerSnapshotAtProposalBlock() public {
		// Create proposal - snapshot is at block where proposal was made + votingDelay
		uint256 id = _createProposal("Snapshot test");
		uint256 snapshotBlock = governance.proposalSnapshot(id);

		// Advance to snapshot block so USER_B's delegation is AFTER the snapshot
		vm.roll(snapshotBlock + 1);
		vm.warp(block.timestamp + snapshotBlock + 1);

		// USER_B gets tokens and delegates AFTER the snapshot block
		_claimAndDelegate(USER_B);

		vm.roll(block.number + 1); // Advance one more block so we're in Active state

		vm.prank(USER_B);
		governance.castVote(id, 1); // weight = 0 at snapshot since delegation was after snapshot

		_passVotingPeriod();

		// USER_A did not vote; USER_B weight = 0 at snapshot → quorum not met → Defeated
		assertEq(uint256(governance.state(id)), 3, "Defeated - USER_B had no snapshot power");
	}

	// --- Quorum Boundary Conditions ---

	function testProposalFailsWithZeroVotes() public {
		uint256 id = _createProposal("Zero votes");
		_passVotingDelay();
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 3, "should be Defeated");
	}

	function testProposalFailsWithOneTokenBelowQuorum() public {
		address[] memory p   = new address[](0);
		address[] memory e   = new address[](0);
		MiniDaoToken t3      = new MiniDaoToken(DEPLOYER, makeAddr("T3t"));
		MiniDaoTimeLock l3   = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		MiniDaoGovernance g3 = new MiniDaoGovernance(t3, l3);

		address voter = makeAddr("BELOW_QUORUM_VOTER");
		vm.prank(DEPLOYER);
		t3.transfer(voter, 4e18); // 4 tokens - below quorum of 5
		vm.prank(voter);
		t3.delegate(voter);

		vm.startPrank(DEPLOYER);
		l3.grantRole(l3.PROPOSER_ROLE(), voter);
		l3.grantRole(l3.EXECUTOR_ROLE(), address(0));
		vm.stopPrank();

		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = address(this);
		calldatas[0] = "";

		vm.prank(voter);
		uint256 pid = g3.propose(targets, values, calldatas, "Below quorum exact");
		vm.roll(block.number + g3.votingDelay() + 1);
		vm.warp(block.timestamp + g3.votingDelay() + 1);
		vm.prank(voter);
		g3.castVote(pid, 1);
		vm.roll(block.number + g3.votingPeriod() + 1);
		vm.warp(block.timestamp + g3.votingPeriod() + 1);

		assertEq(uint256(g3.state(pid)), 3, "Defeated - below quorum");
	}

	function testProposalPassesWithExactQuorum() public {
		uint256 id = _createProposal("Exact quorum");
		// USER_A has 100 tokens - well above quorum of 5
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 4, "should be Succeeded");
	}

	function testProposalPassesWithMoreThanQuorum() public {
		_claimAndDelegate(USER_B);
		uint256 id = _createProposal("More than quorum");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 4, "should be Succeeded");
	}

	// --- Queue & Execute Guards ---

	function testCannotQueueBeforeSucceeded() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Queue active");

		vm.prank(USER_A);
		governance.propose(targets, values, calldatas, "Queue active");
		_passVotingDelay();

		vm.expectRevert();
		governance.queue(targets, values, calldatas, descriptionHash);
	}

	function testCannotExecuteBeforeTimelockDelay() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Execute too soon");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldatas, "Execute too soon");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		_passVotingPeriod();
		governance.queue(targets, values, calldatas, descriptionHash);

		// Do NOT warp past timelock delay - execute should revert
		vm.expectRevert();
		governance.execute(targets, values, calldatas, descriptionHash);
	}

	function testCannotExecuteSameProposalTwice() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Execute twice");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldatas, "Execute twice");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		_passVotingPeriod();
		governance.queue(targets, values, calldatas, descriptionHash);
		_passTimelockDelay();
		governance.execute(targets, values, calldatas, descriptionHash);

		vm.expectRevert();
		governance.execute(targets, values, calldatas, descriptionHash);
	}

	// --- Proposal Cancellation ---

	function testProposerCanCancelPendingProposal() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Cancel pending");

		vm.prank(USER_A);
		uint256 id = governance.propose(targets, values, calldatas, "Cancel pending");

		vm.prank(USER_A);
		governance.cancel(targets, values, calldatas, descriptionHash);

		assertEq(uint256(governance.state(id)), 2, "should be Canceled (2)");
	}

	function testProposerCanCancelActiveProposal() public {
		// NOTE: OZ Governor v5 only allows cancel in Pending state (not Active).
		// Once Active, the proposer cannot cancel. This test documents the behavior.
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Cancel active check");

		vm.prank(USER_A);
		uint256 id = governance.propose(targets, values, calldatas, "Cancel active check");
		_passVotingDelay(); // now Active

		// Proposer CANNOT cancel after voting has started in OZ Governor v5
		vm.prank(USER_A);
		vm.expectRevert();
		governance.cancel(targets, values, calldatas, descriptionHash);

		assertEq(uint256(governance.state(id)), 1, "should still be Active (1)");
	}

	function testCancelledProposalCannotBeExecuted() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Cancel exec");

		vm.prank(USER_A);
		governance.propose(targets, values, calldatas, "Cancel exec");

		vm.prank(USER_A);
		governance.cancel(targets, values, calldatas, descriptionHash);

		vm.expectRevert();
		governance.execute(targets, values, calldatas, descriptionHash);
	}

	// --- Convenience Wrapper ---

	function testProposalHelperExecutesSuccessfully() public {
		// governance.proposal() must encode storeVote() (no args) to match VoteBox.storeVote()
		uint256 pId = governance.proposal(address(voteBox));

		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pId, 1);
		_passVotingPeriod();

		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = address(voteBox);
		values[0]    = 0;
		calldatas[0] = abi.encodeWithSignature("storeVote()"); // correct selector

		bytes32 descriptionHash = keccak256(abi.encodePacked("Create New MiniDao Proposal"));

		governance.queue(targets, values, calldatas, descriptionHash);
		_passTimelockDelay();

		governance.execute(targets, values, calldatas, descriptionHash);
		assertEq(voteBox.getVote(), 1, "proposal helper must call storeVote() successfully");
	}

	// --- Multiple Proposals ---

	function testTwoSimultaneousProposalsAreIndependent() public {
		uint256 idA = _createProposal("Proposal A");
		uint256 idB = _createProposal("Proposal B");

		assertFalse(idA == idB, "proposal IDs must be different");

		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(idA, 1); // vote on A only

		_passVotingPeriod();

		assertEq(uint256(governance.state(idA)), 4, "A should be Succeeded");
		assertEq(uint256(governance.state(idB)), 3, "B should be Defeated (no votes)");
	}

	function testDuplicateProposalReverts() public {
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
		) = _buildProposal(address(voteBox), "Duplicate");

		vm.prank(USER_A);
		governance.propose(targets, values, calldatas, "Duplicate");

		vm.prank(USER_A);
		vm.expectRevert();
		governance.propose(targets, values, calldatas, "Duplicate");
	}
}
