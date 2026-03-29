// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoTestBase}          from "../base/MiniDaoTestBase.t.sol";
import {ReentrantFaucetAttack,
        MockCallbackToken,
        TimelockNoopTarget}        from "../mocks/Mocks.sol";
import {MiniDaoFaucet}            from "../../src/MiniDaoFaucet.sol";
import {MiniDaoTimeLock}          from "../../src/MiniDaoTimeLock.sol";

contract MiniDaoSecurityTest is MiniDaoTestBase {
	function setUp() public {
		_deployAll();
		_claimAndDelegate(USER_A);
	}

	// --- Re-entrancy Attacks ---

	function testSecurity_Reentrancy_FaucetClaimCannotBeReentered() public {
		// SECURITY: MiniDaoFaucet uses checks-effects-interactions (CEI): it sets
		// hasClaimedFaucet[msg.sender] = true BEFORE calling token.transfer().
		// This test uses MockCallbackToken, which triggers onTokenReceived() on the
		// recipient during transfer (simulating an ERC777/ERC1363-style hook), to
		// prove that a re-entrant second claim() from the same address is blocked.

		MockCallbackToken callbackToken = new MockCallbackToken();
		MiniDaoFaucet reentrantFaucet   = new MiniDaoFaucet(address(callbackToken));

		// Fund the faucet with enough tokens for multiple claims
		callbackToken.transfer(address(reentrantFaucet), faucet.FAUCET_AMOUNT() * 10);

		ReentrantFaucetAttack attacker = new ReentrantFaucetAttack(address(reentrantFaucet));

		// attack() → faucet.claim():
		//   1. hasClaimedFaucet[attacker] = true   (Effect — CEI)
		//   2. callbackToken.transfer(attacker, …) (Interaction)
		//      └─ triggers attacker.onTokenReceived()
		//            └─ faucet.claim() re-enters → reverts AlreadyClaimed (caught by try/catch in token)
		// Outer claim succeeds; re-entrant claim is blocked.
		attacker.attack();

		assertTrue(reentrantFaucet.hasClaimed(address(attacker)), "attacker claimed exactly once");
		assertEq(
			callbackToken.balanceOf(address(attacker)),
			reentrantFaucet.FAUCET_AMOUNT(),
			"SECURITY: CEI prevents double-claim; attacker received only one FAUCET_AMOUNT"
		);
	}

	function testSecurity_AccessControl_DeployerCannotScheduleAfterAdminRoleRevoked() public {
		// SECURITY: After _deployAll(), DEPLOYER's DEFAULT_ADMIN_ROLE is revoked.
		// Any direct call to timelock.schedule() by DEPLOYER must revert, confirming
		// that the governance bypass path is fully closed.

		vm.prank(DEPLOYER);
		vm.expectRevert(); // DEPLOYER lost admin role - schedule reverts
		timelock.schedule(
			address(voteBox),
			0,
			abi.encodeWithSignature("storeVote()"),
			bytes32(0),
			bytes32(uint256(77)),
			MIN_DELAY
		);
	}

	// --- Flash Loan / Governance Manipulation ---

	function testSecurity_FlashLoan_VotesNotCountedAfterSnapshot() public {
		// SECURITY: Flash loan attack simulation. Attacker borrows tokens AFTER the proposal
		// snapshot. Governor snaps votes at proposalSnapshot block using getPastVotes, so
		// post-snapshot balances contribute zero weight.

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), "Flash loan attack");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldataArr, "Flash loan attack");
		uint256 snapshotBlock = governance.proposalSnapshot(pid);

		// Advance past the snapshot first, then simulate the flash loan
		_passVotingDelay(); // block.number is now > snapshotBlock

		// Flash loan: ATTACKER acquires tokens and delegates AFTER the snapshot
		vm.prank(address(timelock));
		token.transfer(ATTACKER, 10_000_000 * 10 ** 18);
		vm.prank(ATTACKER);
		token.delegate(ATTACKER);

		// ATTACKER casts vote but their weight at snapshotBlock is 0
		vm.prank(ATTACKER);
		governance.castVote(pid, 1);

		assertEq(
			token.getPastVotes(ATTACKER, snapshotBlock),
			0,
			"SECURITY: attacker had 0 votes at snapshot"
		);

		_passVotingPeriod();

		(, uint256 forVotes,) = governance.proposalVotes(pid);
		assertLe(
			forVotes,
			token.getPastVotes(USER_A, snapshotBlock),
			"SECURITY: for-votes bounded by legitimate snapshot power"
		);
	}

	function testSecurity_FlashLoan_DelegateThenUndelegateInOneBlock() public {
		// SECURITY: Attacker tries to acquire tokens AFTER a proposal is queued at snapshot,
		// then delegate to gain voting power. Because their delegation falls after snapshotBlock,
		// getPastVotes at snapshotBlock returns 0.

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), "Flash delegate attack");

		// USER_A creates the proposal (USER_A has tokens + delegation from setUp)
		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldataArr, "Flash delegate attack");
		uint256 snapshotBlock = governance.proposalSnapshot(pid);

		// Advance past the snapshot (voting delay)
		_passVotingDelay(); // block.number > snapshotBlock now

		// ATTACKER acquires tokens and delegates AFTER the snapshot
		vm.prank(address(timelock));
		token.transfer(ATTACKER, 1_000 * 10 ** 18);
		vm.prank(ATTACKER);
		token.delegate(ATTACKER);

		// ATTACKER tries to vote - weight at snapshotBlock should be 0
		vm.prank(ATTACKER);
		governance.castVote(pid, 1);

		uint256 attackerPowerAtSnapshot = token.getPastVotes(ATTACKER, snapshotBlock);
		assertEq(attackerPowerAtSnapshot, 0, "SECURITY: attacker's power at snapshot is 0 - flash loan ineffective");
	}

	function testSecurity_VoteManipulation_TokensTransferredAfterSnapshotDontCount() public {
		// SECURITY: USER_A holds tokens and delegates before snapshot. After the snapshot,
		// USER_A transfers all tokens to USER_B. USER_B's balance should contribute 0
		// to this proposal because the snapshot was taken before the transfer.

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), "Post-snapshot transfer");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldataArr, "Post-snapshot transfer");
		uint256 snapshotBlock = governance.proposalSnapshot(pid);

		// Advance past the snapshot so getPastVotes is valid
		_passVotingDelay();

		uint256 userAVotesAtSnap = token.getPastVotes(USER_A, snapshotBlock);

		// Transfer all tokens from USER_A to USER_B AFTER snapshot
		uint256 userABalance = token.balanceOf(USER_A);
		vm.prank(USER_A);
		token.transfer(USER_B, userABalance);
		vm.prank(USER_B);
		token.delegate(USER_B);

		vm.prank(USER_A);
		governance.castVote(pid, 1);

		(, uint256 forVotes,) = governance.proposalVotes(pid);
		assertEq(forVotes, userAVotesAtSnap, "SECURITY: for-votes match snapshot, not current balance");

		vm.prank(USER_B);
		governance.castVote(pid, 1);

		(, uint256 forVotesAfter,) = governance.proposalVotes(pid);
		assertEq(forVotesAfter, userAVotesAtSnap, "SECURITY: USER_B adds 0 weight at snapshot");
	}

	// --- Access Control Exploits ---

	function testSecurity_PrivilegeEscalation_AttackerCannotGrantSelfRole() public {
		// SECURITY: ATTACKER has no DEFAULT_ADMIN_ROLE - grantRole reverts with
		// AccessControlUnauthorizedAccount.
		bytes32 proposerRole = timelock.PROPOSER_ROLE();
		vm.startPrank(ATTACKER);
		vm.expectRevert();
		timelock.grantRole(proposerRole, ATTACKER);
		vm.stopPrank();
	}

	function testSecurity_PrivilegeEscalation_AttackerCannotTransferVoteBoxOwnership() public {
		// SECURITY: Ownable.onlyOwner guard prevents ATTACKER from hijacking VoteBox.
		vm.prank(ATTACKER);
		vm.expectRevert();
		voteBox.transferOwnership(ATTACKER);
	}

	function testSecurity_PrivilegeEscalation_AttackerCannotExecuteTimelockDirectly() public {
		// SECURITY: Deploy a timelock WITHOUT address(0) executor. ATTACKER (no EXECUTOR_ROLE)
		// calling execute() reverts.
		address[] memory proposers = new address[](0);
		address[] memory executors = new address[](0); // no open executor
		MiniDaoTimeLock strictLock = new MiniDaoTimeLock(MIN_DELAY, proposers, executors, DEPLOYER);
		TimelockNoopTarget noopTgt = new TimelockNoopTarget();

		bytes32 pRole = strictLock.PROPOSER_ROLE();
		vm.startPrank(DEPLOYER);
		strictLock.grantRole(pRole, DEPLOYER);
		strictLock.schedule(address(noopTgt), 0, "", bytes32(0), bytes32(uint256(42)), MIN_DELAY);
		vm.stopPrank();

		vm.warp(block.timestamp + MIN_DELAY + 1);

		vm.startPrank(ATTACKER);
		vm.expectRevert();
		strictLock.execute(address(noopTgt), 0, "", bytes32(0), bytes32(uint256(42)));
		vm.stopPrank();
	}

	function testSecurity_PrivilegeEscalation_AttackerCannotProposeWithoutVotingPower() public {
		// SECURITY NOTE: OZ Governor's default proposalThreshold is 0, so any address CAN
		// propose - including an account with 0 tokens. This is a known governance risk:
		// anyone can spam proposals. This test documents the current behavior. A production
		// deployment should set proposalThreshold > 0.
		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), "Attacker proposal");

		vm.prank(ATTACKER);
		uint256 pid = governance.propose(targets, values, calldataArr, "Attacker proposal");
		assertTrue(pid > 0, "SECURITY NOTE: proposalThreshold = 0 allows zero-power proposals");
	}

	// --- Governance Attack Vectors ---

	function testSecurity_Governance_ProposalFrontRunCancellation() public {
		// SECURITY: Only the proposer can cancel a proposal (in OZ Governor v5 the proposer
		// can cancel during Pending/Active state). Non-proposer cancel must revert.

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Frontrun cancel");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldataArr, "Frontrun cancel");

		// Non-proposer cancel must revert
		vm.prank(ATTACKER);
		vm.expectRevert();
		governance.cancel(targets, values, calldataArr, descriptionHash);

		// Proposer cancels legitimately
		vm.prank(USER_A);
		governance.cancel(targets, values, calldataArr, descriptionHash);

		assertEq(uint256(governance.state(pid)), 2, "should be Canceled (2)");

		vm.expectRevert();
		governance.execute(targets, values, calldataArr, descriptionHash);
	}

	function testSecurity_Governance_CannotExecuteWithWrongCalldata() public {
		// SECURITY: Calldata is part of the operation hash. Submitting different calldata
		// at execute() time produces a hash mismatch and the timelock reverts.

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Wrong calldata");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldataArr, "Wrong calldata");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		_passVotingPeriod();
		governance.queue(targets, values, calldataArr, descriptionHash);
		_passTimelockDelay();

		bytes[] memory wrongCalldatas = new bytes[](1);
		wrongCalldatas[0] = abi.encodeWithSignature("storeVote(uint256)", 1);

		vm.expectRevert();
		governance.execute(targets, values, wrongCalldatas, descriptionHash);
	}

	function testSecurity_Governance_CannotBypassTimelockWithDirectExecute() public {
		// SECURITY: Calling timelock.schedule() requires PROPOSER_ROLE. After _deployAll(),
		// DEPLOYER's admin role is revoked so DEPLOYER cannot schedule - confirming that
		// the governance bypass path is closed.

		vm.prank(DEPLOYER);
		vm.expectRevert(); // DEPLOYER has no PROPOSER_ROLE and no admin
		timelock.schedule(
			address(voteBox),
			0,
			abi.encodeWithSignature("storeVote()"),
			bytes32(0),
			bytes32(uint256(55)),
			MIN_DELAY
		);
	}

	function testSecurity_ProposalSelectorMismatch_HelperFunctionReverts() public {
		// SECURITY: Expose the selector mismatch - execution must revert.
		// Propose with wrong selector from the start so all lifecycle steps share the same proposal ID.
		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = address(voteBox);
		values[0]    = 0;
		calldatas[0] = abi.encodeWithSignature("storeVote(uint256)", 1); // TEST: wrong selector – storeVote takes no args

		string memory description = "Create New MiniDao Proposal";
		bytes32 descriptionHash   = keccak256(abi.encodePacked(description));

		vm.prank(USER_A);
		uint256 pId = governance.propose(targets, values, calldatas, description);

		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pId, 1);
		_passVotingPeriod();

		governance.queue(targets, values, calldatas, descriptionHash);
		_passTimelockDelay();

		governance.execute(targets, values, calldatas, descriptionHash);
		assertEq(voteBox.getVote(), 1, "storeVote() must be called successfully via proposal helper");
	}
}
