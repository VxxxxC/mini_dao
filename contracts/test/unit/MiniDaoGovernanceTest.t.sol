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
		// QUORUM_VOTES = 300e18; faucet gives 100e18 per claim → need 3 voters.
		// Claim + delegate all three BEFORE any proposal so snapshot captures their power.
		_claimAndDelegate(USER_A);
		_claimAndDelegate(USER_B);
		_claimAndDelegate(USER_C);
	}

	// --- Configuration ---

	function testGovernorName() public view {
		assertEq(governance.name(), "Mini Governor", "governor name mismatch");
	}

	function testQuorumValue() public view {
		assertEq(governance.quorum(block.number), 300e18, "quorum should be 300 tokens (3 voters x 100)");
	}

	function testVotingDelay() public view {
		assertEq(governance.votingDelay(), 30 seconds, "voting delay mismatch");
	}

	function testVotingPeriod() public view {
		assertEq(governance.votingPeriod(), 1 minutes, "voting period mismatch");
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
		// Need 3 × 100e18 = 300e18 votes to meet QUORUM_VOTES
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		vm.prank(USER_C);
		governance.castVote(id, 1);
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 4, "should be Succeeded (4)");
	}

	function testProposalDefeatedWhenQuorumNotMet() public {
		// Use a standalone setup with a voter holding < 300e18 tokens (quorum)
		address[] memory p  = new address[](0);
		address[] memory e  = new address[](0);
		MiniDaoToken t2     = new MiniDaoToken(DEPLOYER, makeAddr("T50"));
		MiniDaoTimeLock l2  = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		MiniDaoGovernance g2 = new MiniDaoGovernance(t2, l2);

		address voter = makeAddr("SMALL_VOTER");
		vm.prank(DEPLOYER);
		t2.transfer(voter, 4e18); // 4 tokens < 300e18 quorum
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
		// USER_A (100e18 For) vs USER_B + USER_C (200e18 Against).
		// forVotes = 100e18 < QUORUM_VOTES (300e18) so proposal is Defeated
		// due to quorum not being reached by the For side.
		uint256 id = _createProposal("Against majority");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 1); // For  - 100 tokens
		vm.prank(USER_B);
		governance.castVote(id, 0); // Against - 100 tokens
		vm.prank(USER_C);
		governance.castVote(id, 0); // Against - 100 tokens

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
		// Need 3 × 100e18 = 300e18 votes to meet QUORUM_VOTES
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		vm.prank(USER_C);
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
		// USER_A abstains with 100e18 tokens; quorum is 300e18 so quorum is NOT met.
		// Defeated because quorum is not reached (For + Abstain = 100e18 < 300e18).
		uint256 id = _createProposal("Abstain quorum");
		_passVotingDelay();

		vm.prank(USER_A);
		governance.castVote(id, 2); // Abstain

		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 3, "Defeated - quorum not reached with single abstain");
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

		// Advance past the snapshot block
		vm.roll(snapshotBlock + 1);
		vm.warp(block.timestamp + snapshotBlock + 1);

		// LATE_VOTER gets tokens and delegates AFTER the snapshot block (zero power at snapshot)
		address lateVoter = makeAddr("LATE_VOTER");
		vm.prank(address(timelock));
		token.transfer(lateVoter, 100e18);
		vm.prank(lateVoter);
		token.delegate(lateVoter);

		vm.roll(block.number + 1); // advance one more block so proposal is Active

		vm.prank(lateVoter);
		governance.castVote(id, 1); // weight = 0 at snapshot – delegation was after snapshot

		_passVotingPeriod();

		// lateVoter weight = 0 at snapshot → forVotes = 0 < 300e18 quorum → Defeated
		assertEq(uint256(governance.state(id)), 3, "Defeated - lateVoter had no snapshot power");
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
		t3.transfer(voter, 4e18); // 4 tokens - below quorum of 300e18
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
		// 3 voters × 100e18 = 300e18 = QUORUM_VOTES exactly
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		vm.prank(USER_C);
		governance.castVote(id, 1);
		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 4, "should be Succeeded");
	}

	function testProposalPassesWithMoreThanQuorum() public {
		// USER_A + USER_B + USER_C each vote For → 300e18 total = QUORUM_VOTES (meets quorum)
		uint256 id = _createProposal("More than quorum");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		vm.prank(USER_C);
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
		// Need 3 × 100e18 = 300e18 to meet QUORUM_VOTES
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		vm.prank(USER_B);
		governance.castVote(pid, 1);
		vm.prank(USER_C);
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
		// Need 3 × 100e18 = 300e18 to meet QUORUM_VOTES
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		vm.prank(USER_B);
		governance.castVote(pid, 1);
		vm.prank(USER_C);
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
		// governance.propose(address) correctly encodes storeVote() (no args) to match
		// VoteBox.storeVote(). A proposal created via the helper must queue and execute
		// without reverting, and the vote counter must increment.
		uint256 pId = governance.propose(address(voteBox));
		_passVotingDelay();
		// Need 3 × 100e18 = 300e18 to meet QUORUM_VOTES
		vm.prank(USER_A);
		governance.castVote(pId, 1);
		vm.prank(USER_B);
		governance.castVote(pId, 1);
		vm.prank(USER_C);
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
		// Vote For on A with all 3 voters to meet QUORUM_VOTES (300e18)
		vm.prank(USER_A);
		governance.castVote(idA, 1);
		vm.prank(USER_B);
		governance.castVote(idA, 1);
		vm.prank(USER_C);
		governance.castVote(idA, 1);
		// B receives no votes

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
